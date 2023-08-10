# frozen_string_literal: true

class EmailDataCache
  attr_reader :scope, :max_no_emails_to_store_data

  def initialize(scope, max_no_emails_to_store_data)
    @scope = scope
    @max_no_emails_to_store_data = max_no_emails_to_store_data
  end

  def set(id, data)
    save_data_to_filesystem(id, data)
    cleanup_filesystem_data_store
  end

  def get(id)
    File.read(data_filesystem_path(id)) if data_on_filesystem?(id)
  end

  def data_filesystem_directory
    Rails.root.join("db", "emails", scope)
  end

  def create_data_filesystem_directory
    FileUtils.mkdir_p(data_filesystem_directory)
  end

  # Won't throw an exception when filename doesn't exist
  def self.safe_file_delete(filename)
    File.delete filename
  rescue Errno::ENOENT
    # Do nothing and return nil if the file doesn't exist
    nil
  end

  # Won't throw an exception when filename doesn't exist
  def self.safe_file_mtime(filename)
    File.mtime filename
  rescue Errno::ENOENT
    # Do nothing and return nil if the file doesn't exist
    nil
  end

  private

  def data_filesystem_path(id)
    File.join(data_filesystem_directory, "#{id}.eml")
  end

  def data_on_filesystem?(id)
    File.exist?(data_filesystem_path(id))
  end

  def save_data_to_filesystem(id, data)
    # Don't overwrite the data that's already on the filesystem
    return if data_on_filesystem?(id)

    # Save the data part of the email to the filesystem
    create_data_filesystem_directory
    File.binwrite(data_filesystem_path(id), data)
  end

  def cleanup_filesystem_data_store
    # If there are more than a certain number of stored emails on the filesystem
    # remove the oldest ones
    entries = Dir.glob(File.join(data_filesystem_directory, "*"))
    no_to_remove = entries.count - max_no_emails_to_store_data
    return if no_to_remove <= 0

    # Sort entries by modification time where already deleted (nil) and oldest come first
    entries = entries.sort_by do |f|
      m = EmailDataCache.safe_file_mtime(f)
      # This cryptic trick for sorting with nils from
      # https://stackoverflow.com/questions/4475991/sorting-an-array-based-on-an-attribute-that-may-be-nil-in-some-elements
      [m ? 1 : 0, m]
    end
    to_remove = entries[0...no_to_remove]
    to_remove.each { |f| EmailDataCache.safe_file_delete f }
  end
end
