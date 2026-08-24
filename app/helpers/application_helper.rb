module ApplicationHelper
  def initials_for(user)
    return "?" if user.blank?

    if user.name.present?
      user.name.split.map(&:first).first(2).join.upcase
    else
      user.email.first.upcase
    end
  end
end
