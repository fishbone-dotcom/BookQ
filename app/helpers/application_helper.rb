module ApplicationHelper
  def initials_for(user)
    return "?" if user.blank?

    if user.name.present?
      user.name.split.map(&:first).first(2).join.upcase
    else
      user.email.first.upcase
    end
  end

  # Like initials_for, but for an Appointment whose patient may be a guest
  # (no User row) — falls back to the submitted guest name/email.
  def contact_initials_for(appointment)
    name = appointment.contact_name
    email = appointment.contact_email
    return "?" if name.blank? && email.blank?

    name.present? ? name.split.map(&:first).first(2).join.upcase : email.first.upcase
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
