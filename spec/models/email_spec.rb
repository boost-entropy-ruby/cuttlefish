require 'spec_helper'

describe Email do
  describe "#from" do
    it "should return a string for the from email address" do
      email = Email.create!(:from_address => EmailAddress.create!(address: "matthew@foo.com"))
      email.from.should == "matthew@foo.com"
    end

    it "should allow the from_address to be set by a string" do
      email = Email.create!(:from => "matthew@foo.com")
      email.from.should == "matthew@foo.com"
    end
  end

  describe "#from_address" do
    it "should return an EmailAddress object" do
      email = Email.create!(from: "matthew@foo.org")
      a1 = EmailAddress.find_by_address("matthew@foo.org")
      a1.should_not be_nil
      email.from_address.should == a1
    end
  end

  describe "#to" do
    it "should return an array for all the email addresses" do
      email = Email.create!(:to => ["mlandauer@foo.org", "matthew@bar.com"])
      email.to.should == ["mlandauer@foo.org", "matthew@bar.com"]
    end

    it "should be able to give just a single recipient" do
      email = Email.new(:to => "mlandauer@foo.org")
      email.to.should == ["mlandauer@foo.org"]
    end
  end

  describe "#to_addresses" do
    it "should return an array of EmailAddress objects" do
      email = Email.create!(to: ["mlandauer@foo.org", "matthew@bar.com"])
      a1 = EmailAddress.find_by_address("mlandauer@foo.org")
      a2 = EmailAddress.find_by_address("matthew@bar.com")
      a1.should_not be_nil
      a2.should_not be_nil
      email.to_addresses.should == [a1, a2]
    end
  end

  describe "#data" do
    context "one email" do
      before :each do
        @email = Email.create!(id: 10, data: "This is a main data section")
      end
      
      it "should persist the main part of the email in the filesystem" do
        File.read(@email.data_filesystem_path).should == "This is a main data section"
      end

      it "should be able to read in the data again" do
        Email.find(10).data.should == "This is a main data section"
      end

      it "should return nil if nothing is stored on the filesystem" do
        FileUtils::rm_rf(Email.data_filesystem_directory)
        Email.find(10).data.should be_nil
      end
    end

    it "should only keep the full data of a certain number of the emails around" do
      Email.stub!(:max_no_emails_to_store_data).and_return(2)
      4.times { Email.create!(data: "This is a main section") }
      Dir.glob(File.join(Email.data_filesystem_directory, "*")).count.should == 2
    end
  end

  describe ".extract_postfix_queue_id_from_smtp_message" do
    it "should extract the queue id" do
      Email.extract_postfix_queue_id_from_smtp_message("250 2.0.0 Ok: queued as 2F63736D4A27\n").should == "2F63736D4A27"
    end

    it "should ignore any other form" do
      Email.extract_postfix_queue_id_from_smtp_message("250 250 Message accepted").should be_nil
    end
  end

  describe "#update_delivery_status!" do
    context "an email with one recipient" do
      let(:email) { Email.create!(:to => "matthew@foo.com") }

      it "should have an unknown delivery status before anything is done" do
        email.postfix_log_lines.create(:text => "to=<matthew@foo.com>, relay=aspmx.l.google.com[74.125.129.27]:25, delay=2.8, delays=0.07/0.02/1.3/1.5, dsn=2.0.0, status=sent (250 2.0.0 OK 1365207357 ed2si16066733pbb.305 - gsmtp)")
        email.delivered.should be_nil
        email.not_delivered.should be_nil
      end

      it "should be delivered if the status is sent" do
        email.postfix_log_lines.create(:text => "to=<matthew@foo.com>, relay=aspmx.l.google.com[74.125.129.27]:25, delay=2.8, delays=0.07/0.02/1.3/1.5, dsn=2.0.0, status=sent (250 2.0.0 OK 1365207357 ed2si16066733pbb.305 - gsmtp)")
        email.update_delivery_status!
        email.delivered.should == true
        email.not_delivered.should == false
      end

      it "should not be delivered if the status is deferred" do
        email.postfix_log_lines.create(text: "to=<matthew@foo.com>, relay=foo.bar.com[1.2.3.4]:25, delay=92780, delays=92777/0.03/1.6/0.91, dsn=4.3.0, status=deferred (host foo.bar.com[1.2.3.4] said: 451 4.3.0 <bounces@planningalerts.org.au>: Temporary lookup failure (in reply to RCPT TO command))")
        email.update_delivery_status!
        email.delivered.should == false
        email.not_delivered.should == true
      end

      it "should not update the delivery status if there are no log lines" do
        email.update_delivery_status!
        email.delivered.should be_nil
        email.not_delivered.should be_nil
      end
    end
  end
end
