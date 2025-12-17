ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :username, :name, :bio,
                :profile_type, :sponsor_requests, :subscription_active, :avatar, :admin_created

  index do
    selectable_column
    id_column
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

  filter :username
  filter :name
  filter :email
  filter :profile_type
  filter :subscription_active
  filter :admin_created
  filter :created_at

  show do
    attributes_table do
      row :id
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
      f.input :profile_type, as: :select, collection: ['individual', 'company'], include_blank: false
      f.input :subscription_active
      f.input :sponsor_requests, as: :text
      f.input :avatar, as: :file, hint: "Upload profile avatar"
      f.input :admin_created, hint: "Check this if creating a profile on behalf of someone (they can claim it later)"
    end

    f.inputs "Password" do
      f.input :password
      f.input :password_confirmation
      li "Leave password fields blank to keep current password"
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
