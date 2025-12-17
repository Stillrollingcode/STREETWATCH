ActiveAdmin.register AdminUser do
  permit_params :email, :password, :password_confirmation, :role

  # Only super_admins can manage admin users
  controller do
    def scoped_collection
      if current_admin_user.super_admin?
        super
      else
        raise ActiveAdmin::AccessDenied
      end
    end
  end

  index do
    selectable_column
    id_column
    column :email
    column :role do |admin|
      status_tag admin.role, class: admin.super_admin? ? 'important' : (admin.admin? ? 'yes' : 'ok')
    end
    column :created_at
    column :updated_at
    actions
  end

  filter :email
  filter :role, as: :select, collection: AdminUser::ROLES
  filter :created_at

  show do
    attributes_table do
      row :id
      row :email
      row :role do |admin|
        status_tag admin.role, class: admin.super_admin? ? 'important' : (admin.admin? ? 'yes' : 'ok')
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Admin User Details" do
      f.input :email
      f.input :role, as: :select, collection: AdminUser::ROLES, hint: "super_admin: full access | admin: manage content & users | moderator: manage content only"
      f.input :password
      f.input :password_confirmation
      li "Leave password fields blank to keep current password" if f.object.persisted?
    end
    f.actions
  end
end
