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

  describe "edit profile" do
    it "requires authentication" do
      get edit_user_registration_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the edit form for a signed-in user, with no password fields on it" do
      user = create(:user)
      sign_in user

      get edit_user_registration_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(user.email)
      expect(response.body).not_to include('name="user[password]"')
      expect(response.body).not_to include('name="user[password_confirmation]"')
      expect(response.body).to include("Change Password")
    end

    it "updates the name and email with the current password confirmed" do
      user = create(:user, password: "password123", password_confirmation: "password123")
      sign_in user

      put user_registration_path, params: {
        user: { name: "New Name", email: "updated@example.com", current_password: "password123" }
      }

      user.reload
      expect(user.name).to eq("New Name")
      expect(user.email).to eq("updated@example.com")
    end
  end

  describe "change password" do
    it "requires authentication" do
      get edit_user_change_password_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the change-password form, with no name/email fields on it" do
      user = create(:user)
      sign_in user

      get edit_user_change_password_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('name="user[email]"')
      expect(response.body).not_to include('name="user[name]"')
      expect(response.body).to include('name="user[password]"')
    end

    it "updates the password with the current password confirmed" do
      user = create(:user, password: "password123", password_confirmation: "password123")
      sign_in user

      put user_registration_path, params: {
        user: { password: "newpassword456", password_confirmation: "newpassword456", current_password: "password123" }
      }

      expect(user.reload.valid_password?("newpassword456")).to be true
    end

    it "does not update the password without the correct current password" do
      user = create(:user, password: "password123", password_confirmation: "password123")
      sign_in user

      put user_registration_path, params: {
        user: { password: "newpassword456", password_confirmation: "newpassword456", current_password: "wrongpassword" }
      }

      expect(user.reload.valid_password?("newpassword456")).to be false
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

    it "sends a clinic staffer straight to their staff dashboard instead of the patient home page" do
      staffer = create(:user, password: "password123", password_confirmation: "password123")
      create(:clinic_staff, user: staffer)

      post user_session_path, params: {
        user: { email: staffer.email, password: "password123" }
      }

      expect(response).to redirect_to(staff_dashboard_path)
    end
  end
end
