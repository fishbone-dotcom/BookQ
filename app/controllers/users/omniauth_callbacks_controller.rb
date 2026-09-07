module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      user = User.from_google(request.env["omniauth.auth"])
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      sign_in_and_redirect user, event: :authentication
    end

    def failure
      redirect_to new_user_session_path, alert: "Google sign-in failed — please try again or use email."
    end
  end
end
