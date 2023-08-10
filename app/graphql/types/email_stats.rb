# frozen_string_literal: true

module Types
  class EmailStats < GraphQL::Schema::Object
    description "Statistics over a set of emails"
    field :click_rate, Float,
          null: true,
          description: "Fraction of emails with links that were clicked"
    field :delivered_count, Int,
          null: false,
          description: "Number of emails delivered"
    field :hard_bounce_count, Int,
          null: false,
          description: "Number of emails that hard bounced"
    field :not_sent_count, Int,
          null: false,
          description: "Number of emails not sent because of the deny list"
    field :open_rate, Float,
          null: true,
          description: "Fraction of emails opened"
    field :sent_count, Int,
          null: false,
          description: "Number of emails sent but not yet delivered or bounced"
    field :soft_bounce_count, Int,
          null: false,
          description: "Number of emails that soft bounced"
    field :total_count, Int,
          null: false,
          description: "The total number of emails", method: :count
    field :user_agent_family_counts, [Types::Count],
          null: false,
          description: "Number of times each type of client opened these emails"

    # TODO: Rename this to "in_flight"
    def sent_count
      status_counts["sent"] || 0
    end

    def delivered_count
      status_counts["delivered"] || 0
    end

    def soft_bounce_count
      status_counts["soft_bounce"] || 0
    end

    def hard_bounce_count
      status_counts["hard_bounce"] || 0
    end

    def not_sent_count
      status_counts["not_sent"] || 0
    end

    # Have this here as well just to make things a little easier

    def open_rate
      Delivery.open_rate(object)
    end

    def click_rate
      Delivery.click_rate(object)
    end

    def user_agent_family_counts
      c = object.joins(:open_events).group(:ua_family)
                .order("count_all desc").count
      c.map { |name, count| { name: name, count: count } }
    end

    private

    def status_counts
      object.group("deliveries.status").count
    end
  end
end
