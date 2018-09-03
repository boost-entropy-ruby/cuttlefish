class Types::MutationType < GraphQL::Schema::Object
  field :create_emails, mutation: Mutations::CreateEmails do
    guard ->(object, args, context) {
      app = App.find_by_id(args['appId'])
      !context[:current_admin].nil? && app && AppPolicy.new(context[:current_admin], app).show?
    }
  end
end
