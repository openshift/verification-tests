module BushSlicer
  class SubscriptionPlan
    attr_reader :id

    def initialize(user)
      res = user.get_self
      if res[:success]
        @id = res.dig(:parsed, "metadata", "labels", "openshift.io/plan")
      else
        raise "failed to get user plan: #{res[:response]}"
      end
    end

    def max_projects
      case
      when id.nil?
        nil
      when id.include?('good')
        10
      when id.include?('better')
        20
      when id.include?('best')
        50
      else
        1
      end
    end
  end
end
