require "rails_helper"

RSpec.describe "Authentication", type: :request do
  describe "sign up" do
    it "creates a new user and redirects on success" do
      expect {
        post user_registration_path, params: {
          user: { email: "newuser@example.com", password: "password123", password_confirmation: "password123" }
        }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it "does not create a user when password confirmation does not match" do
      expect {
        post user_registration_path, params: {
          user: { email: "bad@example.com", password: "password123", password_confirmation: "mismatch" }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "log in" do
    it "logs in an existing user with correct credentials" do
      user = create(:user, password: "password123", password_confirmation: "password123")

      post user_session_path, params: {
        user: { email: user.email, password: "password123" }
      }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include(user.email)
    end

    it "rejects an incorrect password" do
      user = create(:user, password: "password123", password_confirmation: "password123")

      post user_session_path, params: {
        user: { email: user.email, password: "wrongpassword" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
