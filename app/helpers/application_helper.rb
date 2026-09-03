module ApplicationHelper
  def initials_for(user)
    return "?" if user.blank?

    if user.name.present?
      user.name.split.map(&:first).first(2).join.upcase
    else
      user.email.first.upcase
    end
  end

  def icon_svg(inner, size: 20, css_class: nil)
    content_tag(:svg, inner.html_safe, width: size, height: size, viewBox: "0 0 24 24",
      fill: "none", stroke: "currentColor", "stroke-width": 2,
      "stroke-linecap": "round", "stroke-linejoin": "round", class: css_class)
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
