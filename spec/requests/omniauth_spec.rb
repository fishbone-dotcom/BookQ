require "rails_helper"

RSpec.describe "Google OAuth sign-in", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  it "signs in a new user via Google and redirects" do
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "999", info: { email: "googleuser@example.com", name: "Google User" }
    )

    get "/users/auth/google_oauth2/callback"

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Google User")

    user = User.find_by(email: "googleuser@example.com")
    expect(user).to be_present
    expect(user.provider).to eq("google_oauth2")
  end

  it "redirects to sign-in with an alert on failure" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    get "/users/auth/google_oauth2/callback"

    expect(response).to redirect_to(new_user_session_path)
  end
end
