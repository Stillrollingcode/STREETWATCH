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
    column "Admin Created" do |user|
      user.admin_created? ? status_tag("yes", class: "ok") : status_tag("no")
    end
    column "Films", :films_count
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
        format.json do
          users = @users.limit(params[:per_page] || 20).map do |user|
            {
              id: user.id,
              username: user.username,
              profile_type: user.profile_type
            }
          end
          render json: users
        end
      end
    end

    def scoped_collection
      super.includes(:avatar_attachment)
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

  member_action :bulk_tag_films, method: :post do
    user = resource
    film_ids = params[:film_ids] || []
    role = params[:role]

    if film_ids.empty?
      render json: { success: false, message: 'No films selected' }, status: :bad_request
      return
    end

    unless ['rider', 'filmer', 'editor', 'company'].include?(role)
      render json: { success: false, message: 'Invalid role' }, status: :bad_request
      return
    end

    success_count = 0
    errors = []

    film_ids.each do |film_id|
      film = Film.find_by(id: film_id)
      next unless film

      begin
        case role
        when 'rider'
          unless film.riders.include?(user)
            film.riders << user
            # Auto-approve the tag since admin is adding it
            approval = film.film_approvals.find_by(approver_id: user.id, approval_type: 'rider')
            approval&.update(status: 'approved')
            success_count += 1
          end
        when 'filmer'
          unless film.filmers.include?(user)
            film.filmers << user
            approval = film.film_approvals.find_by(approver_id: user.id, approval_type: 'filmer')
            approval&.update(status: 'approved')
            success_count += 1
          end
        when 'editor'
          if film.editor_user_id != user.id
            film.update(editor_user_id: user.id)
            approval = film.film_approvals.find_by(approver_id: user.id, approval_type: 'editor')
            approval&.update(status: 'approved')
            success_count += 1
          end
        when 'company'
          unless film.companies.include?(user)
            film.companies << user
            approval = film.film_approvals.find_by(approver_id: user.id, approval_type: 'company')
            approval&.update(status: 'approved')
            success_count += 1
          end
        end
      rescue => e
        errors << "#{film.title}: #{e.message}"
      end
    end

    if success_count > 0
      render json: {
        success: true,
        message: "Successfully tagged #{success_count} film(s) as #{role}. #{errors.any? ? "Errors: #{errors.join(', ')}" : ''}"
      }
    else
      render json: {
        success: false,
        message: "No films were tagged. #{errors.any? ? "Errors: #{errors.join(', ')}" : 'All films may already have this tag.'}"
      }
    end
  end

  member_action :bulk_tag_photos, method: :post do
    user = resource
    photo_ids = params[:photo_ids] || []
    role = params[:role]

    if photo_ids.empty?
      render json: { success: false, message: 'No photos selected' }, status: :bad_request
      return
    end

    unless ['rider', 'photographer', 'company'].include?(role)
      render json: { success: false, message: 'Invalid role' }, status: :bad_request
      return
    end

    success_count = 0
    errors = []

    photo_ids.each do |photo_id|
      photo = Photo.find_by(id: photo_id)
      next unless photo

      begin
        case role
        when 'rider'
          unless photo.riders.include?(user)
            photo.riders << user
            # Auto-approve the tag since admin is adding it
            approval = photo.photo_approvals.find_by(approver_id: user.id, approval_type: 'rider')
            approval&.update(status: 'approved')
            success_count += 1
          end
        when 'photographer'
          if photo.photographer_user_id != user.id
            photo.update(photographer_user_id: user.id)
            approval = photo.photo_approvals.find_by(approver_id: user.id, approval_type: 'photographer')
            approval&.update(status: 'approved')
            success_count += 1
          end
        when 'company'
          if photo.company_user_id != user.id
            photo.update(company_user_id: user.id)
            approval = photo.photo_approvals.find_by(approver_id: user.id, approval_type: 'company')
            approval&.update(status: 'approved')
            success_count += 1
          end
        end
      rescue => e
        errors << "#{photo.title}: #{e.message}"
      end
    end

    if success_count > 0
      render json: {
        success: true,
        message: "Successfully tagged #{success_count} photo(s) as #{role}. #{errors.any? ? "Errors: #{errors.join(', ')}" : ''}"
      }
    else
      render json: {
        success: false,
        message: "No photos were tagged. #{errors.any? ? "Errors: #{errors.join(', ')}" : 'All photos may already have this tag.'}"
      }
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

    # Tagged Films Section (only on edit)
    if f.object.persisted?
      f.inputs "Tagged Films" do
        para do
          films = f.object.all_films
          if films.any?
            content_tag(:div, class: 'tagged-content-list') do
              films.map do |film|
                roles = f.object.film_roles(film).join(", ")
                content_tag(:div, class: 'tagged-item') do
                  content_tag(:div, class: 'tagged-item-info') do
                    (link_to(film.title, admin_film_path(film), target: '_blank') +
                    content_tag(:span, " (#{roles}) - #{film.release_date&.year || 'N/A'}", class: 'tagged-item-meta')).html_safe
                  end
                end
              end.join.html_safe
            end
          else
            content_tag(:p, "No films tagged yet.", style: "color: #999;")
          end
        end

        para do
          content_tag(:div, id: 'bulk-tag-films-section', style: 'margin-top: 20px; padding: 15px; background: #f9f9f9; border-radius: 4px;') do
            content_tag(:h4, 'Bulk Tag Films', style: 'margin-top: 0;') +
            content_tag(:label, 'Search and add films:', style: 'display: block; margin-bottom: 8px; font-weight: 600;') +
            text_field_tag('film_search', '',
              id: 'film-autocomplete-input',
              placeholder: 'Type to search films...',
              style: 'width: 100%; padding: 8px; margin-bottom: 10px; border: 1px solid #ddd; border-radius: 4px;',
              autocomplete: 'off'
            ) +
            content_tag(:div, '', id: 'film-autocomplete-results', style: 'margin-bottom: 15px;') +
            content_tag(:div, '', id: 'selected-films-container') +
            content_tag(:label, 'Tag as:', style: 'display: block; margin: 15px 0 8px; font-weight: 600;') +
            select_tag('film_tag_role',
              options_for_select(['rider', 'filmer', 'editor', 'company'], 'rider'),
              style: 'width: 100%; padding: 8px; margin-bottom: 10px; border: 1px solid #ddd; border-radius: 4px;'
            ) +
            button_tag('Add Selected Films',
              type: 'button',
              id: 'add-films-btn',
              style: 'padding: 10px 20px; background: #5E6469; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 600;'
            )
          end
        end
      end

      # Tagged Photos Section
      f.inputs "Tagged Photos" do
        para do
          photos = f.object.all_photos
          if photos.any?
            content_tag(:div, class: 'tagged-content-list') do
              photos.map do |photo|
                roles = f.object.photo_roles(photo).join(", ")
                content_tag(:div, class: 'tagged-item') do
                  content_tag(:div, class: 'tagged-item-info') do
                    (link_to(photo.title, admin_photo_path(photo), target: '_blank') +
                    content_tag(:span, " (#{roles}) - #{photo.album&.title || 'No Album'}", class: 'tagged-item-meta')).html_safe
                  end
                end
              end.join.html_safe
            end
          else
            content_tag(:p, "No photos tagged yet.", style: "color: #999;")
          end
        end

        para do
          content_tag(:div, id: 'bulk-tag-photos-section', style: 'margin-top: 20px; padding: 15px; background: #f9f9f9; border-radius: 4px;') do
            content_tag(:h4, 'Bulk Tag Photos', style: 'margin-top: 0;') +
            content_tag(:label, 'Search and add photos:', style: 'display: block; margin-bottom: 8px; font-weight: 600;') +
            text_field_tag('photo_search', '',
              id: 'photo-autocomplete-input',
              placeholder: 'Type to search photos...',
              style: 'width: 100%; padding: 8px; margin-bottom: 10px; border: 1px solid #ddd; border-radius: 4px;',
              autocomplete: 'off'
            ) +
            content_tag(:div, '', id: 'photo-autocomplete-results', style: 'margin-bottom: 15px;') +
            content_tag(:div, '', id: 'selected-photos-container') +
            content_tag(:label, 'Tag as:', style: 'display: block; margin: 15px 0 8px; font-weight: 600;') +
            select_tag('photo_tag_role',
              options_for_select(['rider', 'photographer', 'company'], 'rider'),
              style: 'width: 100%; padding: 8px; margin-bottom: 10px; border: 1px solid #ddd; border-radius: 4px;'
            ) +
            button_tag('Add Selected Photos',
              type: 'button',
              id: 'add-photos-btn',
              style: 'padding: 10px 20px; background: #5E6469; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 600;'
            )
          end
        end
      end
    end

    f.actions

    # Add CSS and JavaScript for the new features
    style type: "text/css" do
      raw %{
        .tagged-content-list {
          max-height: 400px;
          overflow-y: auto;
          border: 1px solid #ddd;
          border-radius: 4px;
          padding: 10px;
          background: white;
        }
        .tagged-item {
          padding: 8px;
          margin-bottom: 6px;
          border-bottom: 1px solid #f0f0f0;
        }
        .tagged-item:last-child {
          border-bottom: none;
        }
        .tagged-item-info {
          display: flex;
          align-items: center;
          gap: 8px;
        }
        .tagged-item-meta {
          color: #666;
          font-size: 13px;
        }
        .autocomplete-results {
          border: 1px solid #ddd;
          border-radius: 4px;
          max-height: 300px;
          overflow-y: auto;
          background: white;
          display: none;
        }
        .autocomplete-results.active {
          display: block;
        }
        .autocomplete-item {
          padding: 10px;
          cursor: pointer;
          border-bottom: 1px solid #f0f0f0;
        }
        .autocomplete-item:hover {
          background: #f5f5f5;
        }
        .autocomplete-item.selected {
          background: #e8f4f8;
        }
        .selected-item {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          padding: 6px 12px;
          margin: 4px;
          background: #e8f4f8;
          border-radius: 4px;
          font-size: 13px;
        }
        .selected-item-remove {
          cursor: pointer;
          color: #999;
          font-weight: bold;
        }
        .selected-item-remove:hover {
          color: #d00;
        }
      }
    end

    # Add JavaScript for username availability checking and autocomplete
    script type: "text/javascript" do
      raw %{
        (function() {
          const usernameInput = document.getElementById('user_username');
          const statusSpan = document.getElementById('username-status');

          if (usernameInput && statusSpan) {
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
          }

          // Autocomplete functionality for films
          const filmInput = document.getElementById('film-autocomplete-input');
          const filmResults = document.getElementById('film-autocomplete-results');
          const selectedFilmsContainer = document.getElementById('selected-films-container');
          const addFilmsBtn = document.getElementById('add-films-btn');
          let selectedFilms = [];
          let filmSearchTimer;

          if (filmInput && filmResults) {
            filmResults.className = 'autocomplete-results';

            filmInput.addEventListener('input', function() {
              const query = this.value.trim();
              clearTimeout(filmSearchTimer);

              if (query.length < 2) {
                filmResults.classList.remove('active');
                return;
              }

              filmSearchTimer = setTimeout(function() {
                fetch('/admin/films.json?q[title_cont]=' + encodeURIComponent(query) + '&per_page=20')
                  .then(res => res.json())
                  .then(data => {
                    filmResults.innerHTML = '';
                    if (data.length > 0) {
                      data.forEach(film => {
                        const div = document.createElement('div');
                        div.className = 'autocomplete-item';
                        div.textContent = film.title + ' (' + (film.release_date ? new Date(film.release_date).getFullYear() : 'N/A') + ')';
                        div.dataset.filmId = film.id;
                        div.dataset.filmTitle = film.title;

                        div.addEventListener('click', function() {
                          const filmId = this.dataset.filmId;
                          const filmTitle = this.dataset.filmTitle;

                          if (!selectedFilms.find(f => f.id == filmId)) {
                            selectedFilms.push({ id: filmId, title: filmTitle });
                            renderSelectedFilms();
                          }

                          filmInput.value = '';
                          filmResults.classList.remove('active');
                        });

                        filmResults.appendChild(div);
                      });
                      filmResults.classList.add('active');
                    } else {
                      filmResults.classList.remove('active');
                    }
                  });
              }, 300);
            });

            function renderSelectedFilms() {
              selectedFilmsContainer.innerHTML = '';
              selectedFilms.forEach((film, index) => {
                const div = document.createElement('div');
                div.className = 'selected-item';
                div.innerHTML = film.title + ' <span class="selected-item-remove" data-index="' + index + '">×</span>';
                selectedFilmsContainer.appendChild(div);
              });

              document.querySelectorAll('.selected-item-remove').forEach(btn => {
                btn.addEventListener('click', function() {
                  const index = parseInt(this.dataset.index);
                  selectedFilms.splice(index, 1);
                  renderSelectedFilms();
                });
              });
            }

            if (addFilmsBtn) {
              addFilmsBtn.addEventListener('click', function() {
                if (selectedFilms.length === 0) {
                  alert('Please select at least one film');
                  return;
                }

                const role = document.getElementById('film_tag_role').value;
                const userId = #{f.object.id};
                const filmIds = selectedFilms.map(f => f.id);

                fetch('/admin/users/' + userId + '/bulk_tag_films', {
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                  },
                  body: JSON.stringify({ film_ids: filmIds, role: role })
                })
                .then(res => res.json())
                .then(data => {
                  if (data.success) {
                    alert(data.message || 'Films tagged successfully!');
                    location.reload();
                  } else {
                    alert('Error: ' + (data.message || 'Failed to tag films'));
                  }
                })
                .catch(err => {
                  alert('Error: ' + err.message);
                });
              });
            }
          }

          // Autocomplete functionality for photos
          const photoInput = document.getElementById('photo-autocomplete-input');
          const photoResults = document.getElementById('photo-autocomplete-results');
          const selectedPhotosContainer = document.getElementById('selected-photos-container');
          const addPhotosBtn = document.getElementById('add-photos-btn');
          let selectedPhotos = [];
          let photoSearchTimer;

          if (photoInput && photoResults) {
            photoResults.className = 'autocomplete-results';

            photoInput.addEventListener('input', function() {
              const query = this.value.trim();
              clearTimeout(photoSearchTimer);

              if (query.length < 2) {
                photoResults.classList.remove('active');
                return;
              }

              photoSearchTimer = setTimeout(function() {
                fetch('/admin/photos.json?q[title_cont]=' + encodeURIComponent(query) + '&per_page=20')
                  .then(res => res.json())
                  .then(data => {
                    photoResults.innerHTML = '';
                    if (data.length > 0) {
                      data.forEach(photo => {
                        const div = document.createElement('div');
                        div.className = 'autocomplete-item';
                        div.textContent = photo.title + ' (Album: ' + (photo.album_title || 'N/A') + ')';
                        div.dataset.photoId = photo.id;
                        div.dataset.photoTitle = photo.title;

                        div.addEventListener('click', function() {
                          const photoId = this.dataset.photoId;
                          const photoTitle = this.dataset.photoTitle;

                          if (!selectedPhotos.find(p => p.id == photoId)) {
                            selectedPhotos.push({ id: photoId, title: photoTitle });
                            renderSelectedPhotos();
                          }

                          photoInput.value = '';
                          photoResults.classList.remove('active');
                        });

                        photoResults.appendChild(div);
                      });
                      photoResults.classList.add('active');
                    } else {
                      photoResults.classList.remove('active');
                    }
                  });
              }, 300);
            });

            function renderSelectedPhotos() {
              selectedPhotosContainer.innerHTML = '';
              selectedPhotos.forEach((photo, index) => {
                const div = document.createElement('div');
                div.className = 'selected-item';
                div.innerHTML = photo.title + ' <span class="selected-item-remove" data-index="' + index + '">×</span>';
                selectedPhotosContainer.appendChild(div);
              });

              document.querySelectorAll('#selected-photos-container .selected-item-remove').forEach(btn => {
                btn.addEventListener('click', function() {
                  const index = parseInt(this.dataset.index);
                  selectedPhotos.splice(index, 1);
                  renderSelectedPhotos();
                });
              });
            }

            if (addPhotosBtn) {
              addPhotosBtn.addEventListener('click', function() {
                if (selectedPhotos.length === 0) {
                  alert('Please select at least one photo');
                  return;
                }

                const role = document.getElementById('photo_tag_role').value;
                const userId = #{f.object.id};
                const photoIds = selectedPhotos.map(p => p.id);

                fetch('/admin/users/' + userId + '/bulk_tag_photos', {
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                  },
                  body: JSON.stringify({ photo_ids: photoIds, role: role })
                })
                .then(res => res.json())
                .then(data => {
                  if (data.success) {
                    alert(data.message || 'Photos tagged successfully!');
                    location.reload();
                  } else {
                    alert('Error: ' + (data.message || 'Failed to tag photos'));
                  }
                })
                .catch(err => {
                  alert('Error: ' + err.message);
                });
              });
            }
          }

          // Close autocomplete results when clicking outside
          document.addEventListener('click', function(e) {
            if (filmResults && !filmInput.contains(e.target) && !filmResults.contains(e.target)) {
              filmResults.classList.remove('active');
            }
            if (photoResults && !photoInput.contains(e.target) && !photoResults.contains(e.target)) {
              photoResults.classList.remove('active');
            }
          });
        })();
      }
    end

  end
end
