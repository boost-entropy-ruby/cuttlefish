class Types::BlockedAddress < GraphQL::Schema::Object
  field :id, ID, null: false, description: "The database ID"
  field :address, String, null: false, description: "Email address"
  field :because_of_delivery_event, Types::DeliveryEvent, null: true, description: "The delivery attempt that bounced that caused this address to be blocked"

  def address
    object.address.text
  end

  def because_of_delivery_event
    object.caused_by_postfix_log_line
  end
end
