# frozen_string_literal: true

require "spec_helper"

describe Address do
  context "with three emails" do
    let(:address1) { described_class.create!(text: "matthew@foo.com") }
    let(:address2) { described_class.create!(text: "peter@bar.com") }

    before do
      @email1 = create(
        :email, from_address: address1, to_addresses: [address1]
      )
      @email2 = create(
        :email, from_address: address1, to_addresses: [address2]
      )
      @email3 = create(
        :email, from_address: address2, to_addresses: [address2]
      )
    end

    describe "#emails_sent" do
      it "is able to find all the emails sent from this address" do
        expect(address1.emails_sent.order(:id)).to eq [@email1, @email2]
      end

      it "is able to find all the emails sent from this address" do
        expect(address2.emails_sent).to eq [@email3]
      end
    end

    describe "#emails_received" do
      it "is able to find all the emails received by this address" do
        expect(address1.emails_received).to eq [@email1]
      end

      it "is able to find all the emails received by this address" do
        expect(address2.emails_received).to eq [@email2, @email3]
      end
    end

    describe "#emails" do
      it "is able to find all emails that involved this email address" do
        expect(address1.emails).to contain_exactly(@email1, @email2)
      end

      it "is able to find all emails that involved this email address" do
        expect(address2.emails).to contain_exactly(@email2, @email3)
      end
    end

    describe "#status" do
      it "takes the most recent delivery to this address as the status" do
        delivery2 = Delivery.find_by(email: @email2, address: address2)
        delivery3 = Delivery.find_by(email: @email3, address: address2)
        # TODO: Replace with factory_girl
        delivery2.postfix_log_lines.create!(
          dsn: "4.5.0",
          time: 10.minutes.ago,
          relay: "",
          delay: "",
          delays: "",
          extended_status: ""
        )
        delivery3.postfix_log_lines.create!(
          dsn: "2.0.0",
          time: 5.minutes.ago,
          relay: "",
          delay: "",
          delays: "",
          extended_status: ""
        )
        expect(address2.status).to eq "delivered"
      end

      it "takes the most recent delivery to this address as the status" do
        delivery2 = Delivery.find_by(email: @email2, address: address2)
        delivery3 = Delivery.find_by(email: @email3, address: address2)
        # TODO: Replace with factory_girl
        delivery2.postfix_log_lines.create!(
          dsn: "4.5.0",
          time: 5.minutes.ago,
          relay: "",
          delay: "",
          delays: "",
          extended_status: ""
        )
        delivery3.postfix_log_lines.create!(
          dsn: "2.0.0",
          time: 10.minutes.ago,
          relay: "",
          delay: "",
          delays: "",
          extended_status: ""
        )
        expect(address2.status).to eq "soft_bounce"
      end

      it "is sent if there are no delivery attempts" do
        expect(address2.status).to eq "sent"
      end
    end
  end
end
