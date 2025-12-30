ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :username, :name, :bio,
                :profile_type, :sponsor_requests, :subscription_active, :admin_created, :avatar

  # Add "Select All" action across all pages (positioned before other action items)
  action_item :select_all_users, only: :index do
    link_to "Select All #{collection.total_count} Users",
            admin_users_path(params.to_unsafe_h.merge(select_all: 'true')),
            class: 'button',
            style: 'background: #ff9800; color: white;',
            data: { confirm: "This will select all #{collection.total_count} users across all pages. Continue?" }
  end

  # Add "Select All" action across all pages
  batch_action :bulk_edit_all,
               if: proc { params[:select_all].blank? },
               form: -> {
                 {
                   profile_type: ['individual', 'company', 'crew'],
                   subscription_active: ['true', 'false']
                 }
               } do |ids, inputs|
    # This handles the actual bulk edit
    users = User.where(id: ids)

    users.each do |user|
      user.update(profile_type: inputs[:profile_type]) if inputs[:profile_type].present?
      user.update(subscription_active: inputs[:subscription_active] == 'true') if inputs[:subscription_active].present?
    end

    redirect_to collection_path, notice: "Updated #{users.count} users"
  end

  # Add custom action item for search bar
  action_item :search, only: :index do
    text_node %{
      <div style="display: flex; align-items: center; margin-top: 15px;">
        <form action="#{admin_users_path}" method="get" accept-charset="UTF-8" style="display: flex; gap: 8px; align-items: center;">
          <input
            name="q[username_or_name_or_email_or_bio_cont]"
            type="text"
            placeholder="Search users..."
            value="#{params.dig(:q, :username_or_name_or_email_or_bio_cont)}"
            style="width: 300px; padding: 6px 12px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px;" />
          <input type="submit" value="Search" style="padding: 6px 16px; background: #5E6469; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 13px; white-space: nowrap;" />
          #{params[:q].present? ? '<a href="' + admin_users_path + '" style="padding: 6px 16px; background: #999; color: white; text-decoration: none; border-radius: 4px; display: inline-block; font-size: 13px; white-space: nowrap;">Clear</a>' : ''}
        </form>
      </div>
    }.html_safe
  end

  index do

    selectable_column
    column "ID", :friendly_id
    column :username
    column :name
    column :email
    column :profile_type
    column "Avatar" do |user|
      user.avatar.attached? ? status_tag("yes", class: "ok") : status_tag("no")
    end
    column :subscription_active
    column "Films" do |user|
      user.all_films.count
    end
    column :created_at
    actions
  end

  # Search bar - searches across username, name, email, and bio
  filter :username_or_name_or_email_or_bio_cont,
         as: :string,
         label: 'Search'

  filter :username
  filter :name
  filter :email
  filter :profile_type
  filter :subscription_active
  filter :admin_created
  filter :created_at

  controller do
    after_action :add_select_all_script, only: :index

    def find_resource
      User.find_by_friendly_or_id(params[:id])
    end

    def index
      super do |format|
        format.html do
          if params[:select_all] == 'true'
            # Get all user IDs matching current filters
            @all_user_ids = @users.pluck(:id)
          end
        end
      end
    end

    def add_select_all_script
      return unless @all_user_ids.present?

      response.body = response.body.sub(
        '</body>',
        <<~HTML + '</body>'
          <script type="text/javascript">
            (function() {
              const allIds = #{@all_user_ids.to_json};
              console.log('[SELECT ALL] Script loaded with', allIds.length, 'user IDs');

              function selectAllUsers() {
                console.log('[SELECT ALL] Running selectAllUsers function');

                // Find all checkboxes
                const checkboxes = document.querySelectorAll('.paginated_collection tbody input[type="checkbox"]');
                console.log('[SELECT ALL] Found', checkboxes.length, 'checkboxes');

                let checkedCount = 0;
                checkboxes.forEach(function(checkbox) {
                  const value = parseInt(checkbox.value);
                  if (allIds.includes(value)) {
                    checkbox.checked = true;
                    checkedCount++;

                    // Manually trigger change event for ActiveAdmin
                    const event = new Event('change', { bubbles: true });
                    checkbox.dispatchEvent(event);
                  }
                });

                console.log('[SELECT ALL] Checked', checkedCount, 'checkboxes');

                // Check master checkbox
                const masterCheckbox = document.querySelector('.paginated_collection thead input[type="checkbox"]');
                if (masterCheckbox) {
                  masterCheckbox.checked = true;
                  console.log('[SELECT ALL] Checked master checkbox');
                }

                // Show notification
                const notice = document.createElement('div');
                notice.className = 'flash flash_notice';
                notice.textContent = 'Selected all ' + allIds.length + ' users across all pages. Choose a batch action from the dropdown.';
                notice.style.cssText = 'position: fixed; top: 20px; left: 50%; transform: translateX(-50%); z-index: 10000; padding: 15px 30px; background: #6dd27f; color: white; border-radius: 4px; box-shadow: 0 2px 10px rgba(0,0,0,0.2);';
                document.body.appendChild(notice);

                setTimeout(function() {
                  notice.remove();
                }, 5000);
              }

              // Try multiple times to ensure DOM is ready
              setTimeout(selectAllUsers, 100);
              setTimeout(selectAllUsers, 500);
              setTimeout(selectAllUsers, 1000);
            })();
          </script>
        HTML
      )
    end

    def create
      attrs = normalize_user_params(permitted_params[:user])
      avatar_param = attrs.delete(:avatar) || attrs.delete("avatar")

      if attrs["password"].blank?
        generated = SecureRandom.hex(12)
        attrs["password"] = generated
        attrs["password_confirmation"] = generated
      end

      @user = User.new(attrs)
      @user.skip_confirmation! if @user.respond_to?(:skip_confirmation!)

      if @user.save
        @user.avatar.attach(avatar_param) if avatar_param.present?
        redirect_to admin_user_path(@user), notice: 'User was successfully created.'
      else
        render :new
      end
    end

    def update
      @user = resource
      attrs = normalize_user_params(permitted_params[:user])

      # Handle password updates: only apply if provided
      if attrs["password"].blank? && attrs["password_confirmation"].blank?
        attrs.delete("password")
        attrs.delete("password_confirmation")
        attrs.delete(:password)
        attrs.delete(:password_confirmation)
      end

      avatar_param = attrs.delete(:avatar) || attrs.delete("avatar")

      if @user.update(attrs)
        @user.avatar.attach(avatar_param) if avatar_param.present?
        redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
      else
        render :edit
      end
    end

    private

    def normalize_user_params(raw)
      (raw || {}).respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    end
  end

  action_item :confirm_email, only: :show, if: proc { !resource.confirmed? } do
    link_to "Force Confirm Email", confirm_admin_user_path(resource), method: :put,
      data: { confirm: "Mark this user's email as verified?" }
  end

  member_action :confirm, method: :put do
    if resource.confirmed?
      redirect_to resource_path, notice: "User is already confirmed."
    else
      resource.confirm
      redirect_to resource_path, notice: "User email marked as confirmed."
    end
  end

  show do
    attributes_table do
      row :friendly_id
      row "Database ID", :id
      row :username
      row :name
      row :email
      row :bio
      row :profile_type
      row :subscription_active
      row :sponsor_requests
      row :admin_created
      row :claim_token
      row :claimed_at

      row "Avatar" do |user|
        if user.avatar.attached?
          image_tag url_for(user.avatar), style: "max-width: 200px;"
        end
      end

      row :created_at
      row :updated_at
    end

    panel "User Activity" do
      attributes_table_for user do
        row "Films as Rider" do
          user.rider_films.count
        end
        row "Films as Filmer" do
          user.filmed_films.count
        end
        row "Films as Editor" do
          user.edited_films.count
        end
        row "Total Films" do
          user.all_films.count
        end
        row "Playlists" do
          user.playlists.count
        end
        row "Comments" do
          user.comments.count
        end
        row "Favorites" do
          user.favorites.count
        end
      end
    end

    panel "Recent Films" do
      table_for user.all_films.limit(10) do
        column "Title" do |film|
          link_to film.title, admin_film_path(film)
        end
        column :film_type
        column "Role(s)" do |film|
          user.film_roles(film).join(", ")
        end
        column :release_date
      end
    end

    panel "Recent Comments" do
      table_for user.comments.order(created_at: :desc).limit(10) do
        column "Film" do |comment|
          link_to comment.film.title, admin_film_path(comment.film)
        end
        column :body do |comment|
          truncate(comment.body, length: 100)
        end
        column :created_at
      end
    end
  end

  form html: { id: "user_form" } do |f|
    f.inputs "User Details" do
      f.input :username, input_html: { id: "user_username" }, hint: raw('<span id="username-status" style="font-size: 12px; color: #999;"></span>')
      f.input :name
      f.input :email
      f.input :bio, as: :text
      f.input :profile_type, as: :select, collection: ['individual', 'company', 'crew'], include_blank: false
      f.input :subscription_active
      f.input :sponsor_requests, as: :text
      f.input :avatar, as: :file, hint: "Upload profile avatar"
      f.input :admin_created, hint: "Check this if creating a profile on behalf of someone (they can claim it later)"
    end

    f.inputs "Password" do
      f.input :password, required: false, input_html: { autocomplete: "new-password" }
      f.input :password_confirmation, required: false
      li "Leave blank to keep current password. Fill only to reset."
    end

    f.actions

    # Add JavaScript for username availability checking
    script type: "text/javascript" do
      raw %{
        (function() {
          const usernameInput = document.getElementById('user_username');
          const statusSpan = document.getElementById('username-status');

          if (!usernameInput || !statusSpan) return;

          const originalUsername = usernameInput.value;
          let timer;

          usernameInput.addEventListener('input', function() {
            const val = this.value.trim();

            if (!val || val === originalUsername) {
              statusSpan.textContent = '';
              return;
            }

            statusSpan.textContent = 'Checking...';
            statusSpan.style.color = '#999';

            clearTimeout(timer);
            timer = setTimeout(function() {
              fetch('/username/check?username=' + encodeURIComponent(val), {
                headers: { 'Accept': 'application/json' }
              })
              .then(function(res) { return res.json(); })
              .then(function(data) {
                if (data.available) {
                  statusSpan.textContent = 'Available ✓';
                  statusSpan.style.color = '#6dd27f';
                } else {
                  statusSpan.textContent = 'Taken ✗';
                  statusSpan.style.color = '#ff7b7b';
                }
              })
              .catch(function() {
                statusSpan.textContent = 'Error checking';
                statusSpan.style.color = '#ff7b7b';
              });
            }, 300);
          });
        })();
      }
    end

  end
end
