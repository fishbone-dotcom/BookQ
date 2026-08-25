module Users
  class RegistrationsController < Devise::RegistrationsController
    prepend_before_action :require_authentication_for_password_edit, only: [ :edit_password ]
    prepend_before_action :set_minimum_password_length, only: [ :edit_password ]
    before_action :configure_permitted_parameters

    # GET /users/change_password — password change lives on its own page,
    # separate from Profile (name/email), since they're different concerns.
    def edit_password
      render :edit_password
    end

    protected

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
    end

    # Named distinctly from Devise's own `authenticate_scope!` (which is
    # already `prepend_before_action`-ed for :edit/:update/:destroy in the
    # parent class) — re-registering that exact method name here, even with
    # a different `only:`, clobbers the inherited callback's conditions
    # instead of adding a second one.
    def require_authentication_for_password_edit
      authenticate_scope!
    end
  end
end
