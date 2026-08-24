module ApplicationHelper
  def initials_for(user)
    return "?" if user.blank?

    if user.name.present?
      user.name.split.map(&:first).first(2).join.upcase
    else
      user.email.first.upcase
    end
  end

  def time_of_day_greeting
    hour = Time.current.hour
    if hour < 12
      "Good morning"
    elsif hour < 18
      "Good afternoon"
    else
      "Good evening"
    end
  end
end
