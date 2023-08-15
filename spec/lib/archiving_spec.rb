# frozen_string_literal: true

require "spec_helper"

describe Archiving do
  subject(:archiver) { described_class.new(Logger.new($stdout)) }

  let!(:app) do
    create(:team).apps.create!(
      id: 2,
      name: "Planning Alerts",
      from_domain: "planningalerts.org.au"
    )
  end

  let(:from_address) do
    create(
      :address,
      id: 12,
      text: "bounces@planningalerts.org.au"
    )
  end

  let!(:email) do
    create(
      :email,
      app: app,
      id: 1753541,
      from_address: from_address,
      data_hash: "aa126db79482378ce17b441347926570228f12ef",
      message_id: "538ef46757549_443e4bb0f901893332@kedumba.mail",
      subject: "1 new planning application"
    )
  end

  describe ".archive" do
    before do
      create(
        :delivery,
        created_at: "2014-06-04T20:26:51.000+10:00",
        email: email
      )
    end

    context "when uploading to S3 succeeds" do
      before do
        # Mock the success response from .copy_to_s3
        # rubocop:disable RSpec/SubjectStub
        allow(archiver).to receive(:copy_to_s3).with("2014-06-04").and_return(true)
        # rubocop:enable RSpec/SubjectStub
      end

      it "removes the temp archive file it creates" do
        archiver.archive("2014-06-04", noisy: false)

        expect(File.exist?("db/archive/2014-06-04.tar.gz")).to be false
      end
    end

    context "when uploading to S3 doesn't happen" do
      before do
        # rubocop:disable RSpec/SubjectStub
        allow(archiver).to receive(:copy_to_s3).with("2014-06-04").and_return(nil)
        # rubocop:enable RSpec/SubjectStub
      end

      after do
        # Clean up file created
        File.delete("db/archive/2014-06-04.tar.gz")
      end

      it "does not delete the local copy" do
        archiver.archive("2014-06-04", noisy: false)

        expect(File.exist?("db/archive/2014-06-04.tar.gz")).to be true
      end
    end
  end

  describe ".unarchive" do
    before do
      # rubocop:disable RSpec/SubjectStub
      allow(archiver).to receive(:archive_directory).and_return("spec/fixtures/archive")
      # rubocop:enable RSpec/SubjectStub
    end

    it "reloads deliveries into the database" do
      archiver.unarchive("2014-06-04")

      expect(Delivery.count).to eq 1
    end
  end

  describe ".serialise" do
    let!(:click_event) do
      create(
        :click_event,
        user_agent: "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:24.0) " \
                    "Gecko/20100101 Firefox/24.0",
        ip: "1.2.3.4",
        created_at: "2014-06-04T20:33:53.000+10:00"
      )
    end
    let(:to_address) do
      create(:address, id: 13, text: "foo@gmail.com")
    end
    let(:delivery) do
      create(
        :delivery,
        id: 5,
        email: email,
        address: to_address,
        created_at: "2014-06-04T20:26:51.000+10:00",
        updated_at: "2014-06-04T20:26:55.000+10:00",
        sent: true,
        status: "delivered",
        open_tracked: true,
        postfix_queue_id: "38B72370AC41"
      )
    end
    let(:delivery_link) do
      create(
        :delivery_link,
        delivery: delivery,
        link: create(
          :link,
          id: 321,
          url: "http://www.planningalerts.org.au/alerts/abc1234/unsubscribe"
        )
      )
    end

    before do
      create(
        :open_event,
        delivery: delivery,
        user_agent:
          "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.0.7) " \
          "Gecko/2009021910 Firefox/3.0.7 " \
          "(via ggpht.com GoogleImageProxy)",
        ip: "2.3.4.5",
        created_at: "2014-10-06T16:05:52.000+11:00"
      )
      create(
        :delivery_link,
        delivery: delivery,
        link: create(
          :link,
          id: 123,
          url: "http://www.planningalerts.org.au/alerts/abc1234/area"
        )
      )
      delivery_link
      create(
        :postfix_log_line,
        delivery: delivery,
        time: "2014-06-04T20:26:53.000+10:00",
        relay: "gmail-smtp-in.l.google.com[173.194.79.26]:25",
        delay: "1.7",
        delays: "0.05/0/0.58/1",
        dsn: "2.0.0",
        extended_status:
          "sent (250 2.0.0 OK 1401877617 bh2si4687161pbb.204 - gsmtp)"
      )
      # The above will also update the status of the delivery. So, updated_at will change
      # So just for the tests we'll reset that here to its initial value
      delivery.update_columns(updated_at: "2014-06-04T20:26:55.000+10:00")
      create(:meta_value, email: email, key: "foo", value: "bar")
      create(:meta_value, email: email, key: "wibble", value: "wobble")
    end

    it "produces the same results with a Delivery object " \
       "created directly as one created with .deserialise " \
       "from a previously serialised Delivery" do
      s1 = archiver.serialise(delivery)

      email.destroy
      delivery = archiver.deserialise(s1)
      s2 = archiver.serialise(delivery)

      expect(s1).to eq s2
    end

    it "produces a known result" do
      email.update_columns(
        subject: "1 new planning application",
        message_id: "538ef46757549_443e4bb0f901893332@kedumba.mail"
      )

      create(
        :click_event,
        delivery_link: delivery_link,
        user_agent: "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:24.0) " \
                    "Gecko/20100101 Firefox/24.0",
        ip: "1.2.3.4",
        referer: nil,
        created_at: "2014-06-04T20:33:53.000+10:00"
      )
  
      s = archiver.serialise(delivery)
  
      expect(JSON.parse(s, symbolize_names: true)).to eq(
        id: 5,
        from_address: {
          id: 12,
          text: "bounces@planningalerts.org.au"
        },
        to_address: {
          id: 13,
          text: "foo@gmail.com"
        },
        subject: "1 new planning application",
        sent: true,
        status: "delivered",
        message_id: "538ef46757549_443e4bb0f901893332@kedumba.mail",
        email_id: 1753541,
        data_hash: "aa126db79482378ce17b441347926570228f12ef",
        created_at: "2014-06-04T20:26:51.000+10:00",
        updated_at: "2014-06-04T20:26:55.000+10:00",
        ignore_deny_list: false,
        app: {
          id: 2,
          name: "Planning Alerts",
          # custom_tracking_domain: "email.planningalerts.org.au",
          custom_tracking_domain: nil,
          from_domain: "planningalerts.org.au"
        },
        tracking: {
          open_tracked: true,
          open_events: [
            {
              user_agent:
                "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.0.7) " \
                "Gecko/2009021910 Firefox/3.0.7 (via ggpht.com GoogleImageProxy)",
              referer: nil,
              ip: "2.3.4.5",
              created_at: "2014-10-06T16:05:52.000+11:00"
            }
          ],
          links: [
            {
              id: 123,
              url: "http://www.planningalerts.org.au/alerts/abc1234/area",
              click_events: []
            },
            {
              id: 321,
              url: "http://www.planningalerts.org.au/alerts/abc1234/unsubscribe",
              click_events: [
                {
                  user_agent: "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:24.0) " \
                              "Gecko/20100101 Firefox/24.0",
                  referer: nil,
                  ip: "1.2.3.4",
                  created_at: "2014-06-04T20:33:53.000+10:00"
                }
              ]
            }
          ],
          postfix_queue_id: "38B72370AC41",
          postfix_log_lines: [
            {
              time: "2014-06-04T20:26:53.000+10:00",
              relay: "gmail-smtp-in.l.google.com[173.194.79.26]:25",
              delay: "1.7",
              delays: "0.05/0/0.58/1",
              dsn: "2.0.0",
              extended_status:
                "sent (250 2.0.0 OK 1401877617 bh2si4687161pbb.204 - gsmtp)"
            }
          ]
        },
        meta_values: {
          foo: "bar",
          wibble: "wobble"
        }
      )
    end
  end

  describe ".copy_to_s3" do
    context "when AWS access is configured" do
      around do |test|
        with_modified_env mock_aws_credentials do
          test.run
        end
      end

      before do
        fixture_archive_file = File.open(
          "spec/fixtures/archive/2014-06-04.tar.gz"
        )
        allow(File).to receive(:open).with("db/archive/2014-06-04.tar.gz") do
          fixture_archive_file
        end
      end

      it "sends a copy to S3" do
        VCR.use_cassette("aws") do
          # TODO: Silence debugging output from this method
          expect(archiver.copy_to_s3("2014-06-04", noisy: false)).to be_instance_of(
            Fog::Storage::AWS::File
          )
        end
      end
    end

    context "when AWS access is not configured" do
      around do |test|
        with_modified_env aws_credentials_missing do
          test.run
        end
      end

      it "fails silently" do
        # TODO: Silence debugging output from this method
        expect(archiver.copy_to_s3("2014-06-04", noisy: false)).to eq nil
      end
    end
  end
end

def mock_aws_credentials
  {
    S3_BUCKET: "fake-s3-bucket",
    AWS_ACCESS_KEY_ID: "fake-aws-access-key-id",
    AWS_SECRET_ACCESS_KEY: "fake-aws-secret-access-key"
  }
end

def aws_credentials_missing
  {
    S3_BUCKET: nil,
    AWS_ACCESS_KEY_ID: nil,
    AWS_SECRET_ACCESS_KEY: nil
  }
end

def with_modified_env(options, &block)
  ClimateControl.modify(options, &block)
end
