class AddDoctorFieldsToClinicStaffs < ActiveRecord::Migration[8.1]
  def change
    add_column :clinic_staffs, :specialization, :string
    add_column :clinic_staffs, :phone, :string
    add_column :clinic_staffs, :status, :integer, default: 0, null: false
  end
end
