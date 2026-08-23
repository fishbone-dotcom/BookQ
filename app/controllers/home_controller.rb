class HomeController < ApplicationController
  def index
    @clinics = Clinic.order(:name) if user_signed_in?
  end
end
