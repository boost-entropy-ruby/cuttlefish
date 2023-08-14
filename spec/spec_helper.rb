# frozen_string_literal: true

require "simplecov"
require "coveralls"

module SignInTestHelpers
  # This can be accessed from any rspec controller test
  def sign_in(admin)
    # We're not putting an expiry on this JSON web token, though we could
    session[:jwt_token] = JWT.encode({ admin_id: admin.id }, ENV.fetch("JWT_SECRET", nil), "HS512")
  end
end

# Generate coverage locally in html as well as in coveralls.io
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ]
)
SimpleCov.start("rails")

require "capybara/rspec"
# PhantomJS currently has some issues with font loading. So, for the time being
# using selenium instead
# require 'capybara/poltergeist'
# Capybara.javascript_driver = :poltergeist
require "database_cleaner"

# DatabaseCleaner.strategy = :truncation

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
require "rspec/rails"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
end

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = Rails.root.join("spec/fixtures")

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.before do
    cache = EmailDataCache.new(
      Rails.env.to_s, Rails.configuration.max_no_emails_to_store
    )
    FileUtils.rm_rf cache.data_filesystem_directory
  end

  config.after do
    cache = EmailDataCache.new(
      Rails.env.to_s, Rails.configuration.max_no_emails_to_store
    )
    FileUtils.rm_rf cache.data_filesystem_directory
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:transaction)
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  config.include FactoryBot::Syntax::Methods
  config.include SignInTestHelpers, type: :controller
end
