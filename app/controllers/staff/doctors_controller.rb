module Staff
  class DoctorsController < BaseController
    before_action :require_owner!, only: [ :new, :create ]

    def index
      @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")
    end

    def new
    end

    def create
      user = find_or_build_user

      unless user.persisted? ? true : user.save
        flash.now[:alert] = user.errors.full_messages.to_sentence
        return render :new, status: :unprocessable_entity
      end

      clinic_staff = @clinic.clinic_staffs.build(
        user: user,
        specialization: params[:specialization],
        phone: params[:phone],
        status: params[:status].presence || :available
      )

      if clinic_staff.save
        redirect_to staff_doctors_path, notice: "#{user.display_name} added to the clinic."
      else
        flash.now[:alert] = clinic_staff.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    private

    def require_owner!
      redirect_to staff_doctors_path, alert: "Only clinic owners can add doctors." unless @clinic_staff&.owner?
    end

    # Find an existing account by email so an already-registered doctor (maybe
    # staffing another clinic) just gets attached here; otherwise create a new
    # staff account with a random password — the owner never gets to set
    # another person's password, and the actual invite-email flow is out of
    # scope for v1 (see docs/admin_portal/04_add_doctor.md).
    def find_or_build_user
      email = params[:email].to_s.strip.downcase
      User.find_by(email: email) || User.new(
        email: email,
        name: params[:name],
        role: :staff,
        password: SecureRandom.hex(12)
      )
    end
  end
end
