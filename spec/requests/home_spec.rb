require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "when signed out" do
      it "shows sign up and log in links" do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Sign up")
        expect(response.body).to include("Log in")
      end
    end

    context "when signed in" do
      it "shows the current user's email" do
        user = create(:user)
        sign_in user

        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(user.email)
      end
    end
  end
end
