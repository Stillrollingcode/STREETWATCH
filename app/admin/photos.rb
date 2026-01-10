ActiveAdmin.register Photo do
  permit_params :title, :description, :date_taken, :album_id, :user_id,
                :photographer_user_id, :company_user_id,
                :custom_photographer_name, :custom_riders, :image,
                rider_ids: []

  # Add "Select All" action across all pages (positioned before other action items)
  action_item :select_all_photos, only: :index do
    link_to "Select All #{collection.total_count} Photos",
            admin_photos_path(params.to_unsafe_h.merge(select_all: 'true')),
            class: 'button',
            style: 'background: #ff9800; color: white;',
            data: { confirm: "This will select all #{collection.total_count} photos across all pages. Continue?" }
  end

  # Add "Select All" action across all pages
  batch_action :bulk_edit_all,
               if: proc { params[:select_all].blank? },
               form: -> {
                 {
                   album_id: Album.all.map { |a| [a.title, a.id] },
                   date_taken: :datepicker
                 }
               } do |ids, inputs|
    # This handles the actual bulk edit
    photos = Photo.where(id: ids)

    photos.each do |photo|
      photo.update(album_id: inputs[:album_id]) if inputs[:album_id].present?
      photo.update(date_taken: inputs[:date_taken]) if inputs[:date_taken].present?
    end

    redirect_to collection_path, notice: "Updated #{photos.count} photos"
  end

  # Add custom action item for search bar
  action_item :search, only: :index do
    text_node %{
      <div style="display: flex; align-items: center; margin-top: 15px;">
        <form action="#{admin_photos_path}" method="get" accept-charset="UTF-8" style="display: flex; gap: 8px; align-items: center;">
          <input
            name="q[title_or_description_or_photographer_user_username_or_user_username_or_riders_username_cont]"
            type="text"
            placeholder="Search photos..."
            value="#{params.dig(:q, :title_or_description_or_photographer_user_username_or_user_username_or_riders_username_cont)}"
            style="width: 300px; padding: 6px 12px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px;" />
          <input type="submit" value="Search" style="padding: 6px 16px; background: #5E6469; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 13px; white-space: nowrap;" />
          #{params[:q].present? ? '<a href="' + admin_photos_path + '" style="padding: 6px 16px; background: #999; color: white; text-decoration: none; border-radius: 4px; display: inline-block; font-size: 13px; white-space: nowrap;">Clear</a>' : ''}
        </form>
      </div>
    }.html_safe
  end

  index do

    selectable_column
    column "ID", :friendly_id
    column "Image" do |photo|
      if photo.image.attached?
        image_tag url_for(photo.image.variant(resize_to_limit: [60, 60])), style: 'max-width: 60px; border-radius: 4px;'
      end
    end
    column :title
    column :album
    column :photographer_name
    column :date_taken
    column :created_at
    actions
  end

  # Search bar - searches across title, description, photographer, and riders
  filter :title_or_description_or_photographer_user_username_or_user_username_or_riders_username_cont,
         as: :string,
         label: 'Search'

  filter :title
  filter :album
  filter :photographer_user, label: 'Photographer'
  filter :user, label: 'Uploader'
  filter :date_taken
  filter :created_at

  controller do
    after_action :add_select_all_script, only: :index

    def find_resource
      Photo.find_by_friendly_or_id(params[:id])
    end

    def index
      super do |format|
        format.html do
          if params[:select_all] == 'true'
            # Get all photo IDs matching current filters
            @all_photo_ids = @photos.pluck(:id)
          end
        end
        format.json do
          photos = @photos.includes(:album).limit(params[:per_page] || 20).map do |photo|
            {
              id: photo.id,
              title: photo.title,
              album_title: photo.album&.title,
              date_taken: photo.date_taken
            }
          end
          render json: photos
        end
      end
    end

    def add_select_all_script
      return unless @all_photo_ids.present?

      response.body = response.body.sub(
        '</body>',
        <<~HTML + '</body>'
          <script type="text/javascript">
            (function() {
              const allIds = #{@all_photo_ids.to_json};
              console.log('[SELECT ALL] Script loaded with', allIds.length, 'photo IDs');

              function selectAllPhotos() {
                console.log('[SELECT ALL] Running selectAllPhotos function');

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
                notice.textContent = 'Selected all ' + allIds.length + ' photos across all pages. Choose a batch action from the dropdown.';
                notice.style.cssText = 'position: fixed; top: 20px; left: 50%; transform: translateX(-50%); z-index: 10000; padding: 15px 30px; background: #6dd27f; color: white; border-radius: 4px; box-shadow: 0 2px 10px rgba(0,0,0,0.2);';
                document.body.appendChild(notice);

                setTimeout(function() {
                  notice.remove();
                }, 5000);
              }

              // Try multiple times to ensure DOM is ready
              setTimeout(selectAllPhotos, 100);
              setTimeout(selectAllPhotos, 500);
              setTimeout(selectAllPhotos, 1000);
            })();
          </script>
        HTML
      )
    end
  end

  show do
    attributes_table do
      row "Image" do |photo|
        if photo.image.attached?
          image_tag url_for(photo.image), style: 'max-width: 600px; border-radius: 8px;'
        end
      end
      row :friendly_id
      row "Database ID", :id
      row :title
      row :description
      row :album
      row :photographer_name
      row "Riders" do |photo|
        photo.all_riders.join(', ')
      end
      row :company_name
      row :date_taken
      row "Uploader" do |photo|
        link_to photo.user.name, admin_user_path(photo.user)
      end
      row :created_at
      row :updated_at
    end

    panel "Approvals" do
      table_for photo.photo_approvals.order(created_at: :desc) do
        column :approval_type
        column :approver do |approval|
          link_to approval.approver.name, admin_user_path(approval.approver)
        end
        column :status do |approval|
          status_tag approval.status
        end
        column :rejection_reason
        column :created_at
        column "Actions" do |approval|
          link_to "View", admin_photo_approval_path(approval)
        end
      end
    end

    panel "Comments" do
      table_for photo.photo_comments.top_level.order(created_at: :desc) do
        column :user do |comment|
          link_to comment.user.name, admin_user_path(comment.user)
        end
        column :body do |comment|
          truncate(comment.body, length: 100)
        end
        column :created_at
        column "Actions" do |comment|
          link_to "Edit", edit_admin_photo_comment_path(comment)
        end
      end
    end
  end

  form do |f|
    f.inputs "Photo Details" do
      f.input :title
      f.input :description
      f.input :date_taken
      f.input :album, as: :select, collection: Album.order(:title)

      # Uploader autocomplete
      li class: 'input' do
        text_node %{
          <label class="label">Uploader</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="uploader-search-input" placeholder="Search for user..." value="#{f.object.user&.username}" autocomplete="off" />
            <div class="autocomplete-results" id="uploader-results"></div>
            <input type="hidden" name="photo[user_id]" id="photo_user_id" value="#{f.object.user_id}" />
          </div>
          <p class="inline-hints">The user who uploaded this photo</p>
        }.html_safe
      end

      f.input :image, as: :file, hint: f.object.image.attached? ? image_tag(url_for(f.object.image.variant(resize_to_limit: [200, 200]))) : content_tag(:span, "No image yet")
    end

    f.inputs "Credits" do
      # Photographer autocomplete
      li class: 'input' do
        text_node %{
          <label class="label">Photographer</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="photographer-search-input" placeholder="Search for photographer..." value="#{f.object.photographer_user&.username}" autocomplete="off" />
            <div class="autocomplete-results" id="photographer-results"></div>
            <input type="hidden" name="photo[photographer_user_id]" id="photo_photographer_user_id" value="#{f.object.photographer_user_id}" />
          </div>
          <p class="inline-hints">Select a user or use custom name below</p>
        }.html_safe
      end

      f.input :custom_photographer_name, hint: "Use this if photographer is not in the system"

      # Company autocomplete
      li class: 'input' do
        text_node %{
          <label class="label">Company</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="company-search-input" placeholder="Search for company profile..." value="#{f.object.company_user&.username}" autocomplete="off" />
            <div class="autocomplete-results" id="company-results"></div>
            <input type="hidden" name="photo[company_user_id]" id="photo_company_user_id" value="#{f.object.company_user_id}" />
          </div>
          <p class="inline-hints">Select a company profile</p>
        }.html_safe
      end

      # Riders autocomplete with tag-based selection
      li class: 'input' do
        text_node %{
          <label class="label">Riders</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="riders-search-input" placeholder="Search for riders..." autocomplete="off" />
            <div class="autocomplete-results" id="riders-results"></div>
          </div>
          <div id="selected-riders-list" class="selected-riders-list"></div>
          <div id="riders-hidden-fields"></div>
          <p class="inline-hints">Search and select registered user profiles</p>
        }.html_safe
      end

      f.input :custom_riders, hint: "Comma-separated names for riders not in the system"
    end

    f.actions

    # Embed data and JavaScript together
    li style: 'display:none;' do
      rider_ids = f.object.rider_ids rescue []

      # Load existing users for display, but don't load all users
      existing_riders = f.object.riders.select(:id, :username) rescue []
      existing_photographer = f.object.photographer_user ? { id: f.object.photographer_user.id, username: f.object.photographer_user.username } : nil
      existing_company = f.object.company_user ? { id: f.object.company_user.id, username: f.object.company_user.username } : nil

      photo_data = {
        existingRiderIds: rider_ids,
        existingRiders: existing_riders.map { |u| { id: u.id, username: u.username } },
        existingPhotographer: existing_photographer,
        existingCompany: existing_company
      }

      text_node <<~HTML.html_safe
        <script type='text/javascript'>window.photoFormData = #{photo_data.to_json};</script>
        <style>
          /* Autocomplete components */
          .autocomplete-wrapper {
            position: relative;
            margin-bottom: 10px;
          }

          .autocomplete-input {
            width: 100%;
            padding: 8px 12px;
            font-size: 14px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
          }

          .autocomplete-input:focus {
            outline: none;
            border-color: #5E6469;
          }

          .autocomplete-results {
            position: absolute;
            top: 100%;
            left: 0;
            right: 0;
            background: white;
            border: 1px solid #ddd;
            border-top: none;
            border-radius: 0 0 4px 4px;
            max-height: 240px;
            overflow-y: auto;
            z-index: 100;
            display: none;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
          }

          .autocomplete-results.show {
            display: block;
          }

          .autocomplete-item {
            padding: 10px 12px;
            cursor: pointer;
            transition: background 0.15s;
            font-size: 14px;
          }

          .autocomplete-item:hover,
          .autocomplete-item.selected {
            background: #f0f0f0;
          }

          .autocomplete-item.no-results {
            color: #999;
            cursor: default;
          }

          .selected-riders-list {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-top: 8px;
            min-height: 40px;
            padding: 8px;
            border-radius: 4px;
            background: #f9f9f9;
            border: 1px solid #ddd;
          }

          .selected-rider-tag {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            background: #5E6469;
            border: 1px solid #4a5055;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
            color: white;
          }

          .selected-rider-tag button {
            background: none;
            border: none;
            color: white;
            font-size: 16px;
            cursor: pointer;
            padding: 0;
            margin: 0;
            line-height: 1;
          }

          .selected-rider-tag button:hover {
            color: #ff6b6b;
          }
        </style>

        <script>
          (function() {
            // No longer loading all users upfront - will fetch via AJAX
            let initialized = false;

            function initAdminAutocomplete() {
              if (initialized) return;
              initialized = true;

              // Initialize single-select autocomplete for uploader, photographer, company
              initSingleAutocomplete('uploader', 'photo_user_id', false);
              initSingleAutocomplete('photographer', 'photo_photographer_user_id', false);
              initSingleAutocomplete('company', 'photo_company_user_id', true);

              // Initialize multi-select autocomplete for riders
              initRidersAutocomplete();
            }

            function initSingleAutocomplete(fieldName, hiddenFieldId, companiesOnly) {
              const input = document.getElementById(fieldName + '-search-input');
              const resultsDiv = document.getElementById(fieldName + '-results');
              const hiddenField = document.getElementById(hiddenFieldId);

              if (!input || !resultsDiv || !hiddenField) return;

              let currentFocus = -1;
              let searchTimer;

              input.addEventListener('focus', function() {
                if (this.value.trim().length >= 2) {
                  showResults(this.value);
                }
              });

              input.addEventListener('input', function() {
                const value = this.value.trim();
                if (value.length === 0) {
                  hideResults();
                  hiddenField.value = '';
                  return;
                }
                if (value.length < 2) {
                  hideResults();
                  return;
                }
                clearTimeout(searchTimer);
                searchTimer = setTimeout(function() {
                  showResults(value);
                }, 300);
              });

              input.addEventListener('keydown', function(e) {
                const items = resultsDiv.querySelectorAll('.autocomplete-item:not(.no-results)');
                if (e.key === 'ArrowDown') {
                  e.preventDefault();
                  currentFocus++;
                  addActive(items);
                } else if (e.key === 'ArrowUp') {
                  e.preventDefault();
                  currentFocus--;
                  addActive(items);
                } else if (e.key === 'Enter') {
                  e.preventDefault();
                  if (currentFocus > -1 && items[currentFocus]) {
                    items[currentFocus].click();
                  } else {
                    hideResults();
                  }
                } else if (e.key === 'Escape') {
                  hideResults();
                }
              });

              function showResults(searchTerm) {
                resultsDiv.innerHTML = '<div class="autocomplete-item no-results">Loading...</div>';
                resultsDiv.classList.add('show');

                // Build URL with optional company filter
                let url = '/admin/users.json?q[username_cont]=' + encodeURIComponent(searchTerm) + '&per_page=10';
                if (companiesOnly) {
                  url += '&q[profile_type_eq]=company';
                }

                fetch(url)
                  .then(res => res.json())
                  .then(data => {
                    resultsDiv.innerHTML = '';
                    currentFocus = -1;

                    if (data.length === 0) {
                      resultsDiv.innerHTML = '<div class="autocomplete-item no-results">No users found</div>';
                    } else {
                      data.forEach(user => {
                        const div = document.createElement('div');
                        div.className = 'autocomplete-item';
                        div.textContent = user.username;
                        div.addEventListener('click', function() {
                          selectUser(user);
                        });
                        resultsDiv.appendChild(div);
                      });
                    }

                    resultsDiv.classList.add('show');
                  })
                  .catch(err => {
                    console.error(`${fieldName} autocomplete error:`, err);
                    resultsDiv.innerHTML = '<div class="autocomplete-item no-results">Error loading users</div>';
                  });
              }

              function hideResults() {
                resultsDiv.classList.remove('show');
                currentFocus = -1;
              }

              function selectUser(user) {
                input.value = user.username;
                hiddenField.value = user.id;
                hideResults();
              }

              function addActive(items) {
                if (!items || items.length === 0) return;
                removeActive(items);
                if (currentFocus >= items.length) currentFocus = 0;
                if (currentFocus < 0) currentFocus = items.length - 1;
                items[currentFocus].classList.add('selected');
              }

              function removeActive(items) {
                items.forEach(item => item.classList.remove('selected'));
              }

              document.addEventListener('click', function(e) {
                if (!input.contains(e.target) && !resultsDiv.contains(e.target)) {
                  hideResults();
                }
              });
            }

            function initRidersAutocomplete() {
              const searchInput = document.getElementById('riders-search-input');
              const resultsDiv = document.getElementById('riders-results');
              const selectedList = document.getElementById('selected-riders-list');
              const hiddenFieldsContainer = document.getElementById('riders-hidden-fields');

              if (!searchInput || !resultsDiv || !selectedList) return;

              const selectedRiders = new Map();
              let currentFocus = -1;
              let searchTimer;

              // Load existing riders
              const existingRiders = window.photoFormData?.existingRiders || [];
              if (existingRiders && existingRiders.length > 0) {
                existingRiders.forEach(rider => {
                  selectedRiders.set(rider.id, rider);
                });
                renderSelectedRiders();
              }

              searchInput.addEventListener('focus', function() {
                if (this.value.trim().length >= 2) {
                  showResults(this.value);
                }
              });

              searchInput.addEventListener('input', function() {
                const value = this.value.trim();
                if (value.length === 0) {
                  hideResults();
                  return;
                }
                if (value.length < 2) {
                  hideResults();
                  return;
                }
                clearTimeout(searchTimer);
                searchTimer = setTimeout(function() {
                  showResults(value);
                }, 300);
              });

              searchInput.addEventListener('keydown', function(e) {
                const items = resultsDiv.querySelectorAll('.autocomplete-item:not(.no-results)');
                if (e.key === 'ArrowDown') {
                  e.preventDefault();
                  currentFocus++;
                  addActive(items);
                } else if (e.key === 'ArrowUp') {
                  e.preventDefault();
                  currentFocus--;
                  addActive(items);
                } else if (e.key === 'Enter') {
                  e.preventDefault();
                  if (currentFocus > -1 && items[currentFocus]) {
                    items[currentFocus].click();
                  } else {
                    hideResults();
                  }
                } else if (e.key === 'Escape') {
                  hideResults();
                }
              });

              function showResults(searchTerm) {
                resultsDiv.innerHTML = '<div class="autocomplete-item no-results">Loading...</div>';
                resultsDiv.classList.add('show');

                fetch('/admin/users.json?q[username_cont]=' + encodeURIComponent(searchTerm) + '&per_page=10')
                  .then(res => res.json())
                  .then(data => {
                    const filtered = data.filter(u => !selectedRiders.has(u.id));

                    resultsDiv.innerHTML = '';
                    currentFocus = -1;

                    if (filtered.length === 0) {
                      resultsDiv.innerHTML = '<div class="autocomplete-item no-results">No riders found</div>';
                    } else {
                      filtered.forEach(user => {
                        const div = document.createElement('div');
                        div.className = 'autocomplete-item';
                        div.textContent = user.username;
                        div.addEventListener('click', function() {
                          addRider(user);
                        });
                        resultsDiv.appendChild(div);
                      });
                    }

                    resultsDiv.classList.add('show');
                  })
                  .catch(err => {
                    console.error('Riders autocomplete error:', err);
                    resultsDiv.innerHTML = '<div class="autocomplete-item no-results">Error loading users</div>';
                  });
              }

              function hideResults() {
                resultsDiv.classList.remove('show');
                currentFocus = -1;
              }

              function addRider(rider) {
                selectedRiders.set(rider.id, rider);
                renderSelectedRiders();
                searchInput.value = '';
                hideResults();
                searchInput.focus();
              }

              function removeRider(riderId) {
                selectedRiders.delete(riderId);
                renderSelectedRiders();
              }

              function renderSelectedRiders() {
                selectedList.innerHTML = '';
                selectedRiders.forEach((rider, id) => {
                  const tag = document.createElement('div');
                  tag.className = 'selected-rider-tag';
                  tag.innerHTML = '<span>' + rider.username + '</span><button type="button" class="remove-rider-btn" data-rider-id="' + id + '">×</button>';
                  selectedList.appendChild(tag);
                });

                hiddenFieldsContainer.innerHTML = '';
                selectedRiders.forEach((rider, id) => {
                  const input = document.createElement('input');
                  input.type = 'hidden';
                  input.name = 'photo[rider_ids][]';
                  input.value = id;
                  hiddenFieldsContainer.appendChild(input);
                });

                selectedList.querySelectorAll('.remove-rider-btn').forEach(btn => {
                  btn.addEventListener('click', function() {
                    const riderId = parseInt(this.getAttribute('data-rider-id'));
                    removeRider(riderId);
                  });
                });
              }

              function addActive(items) {
                if (!items || items.length === 0) return;
                removeActive(items);
                if (currentFocus >= items.length) currentFocus = 0;
                if (currentFocus < 0) currentFocus = items.length - 1;
                items[currentFocus].classList.add('selected');
              }

              function removeActive(items) {
                items.forEach(item => item.classList.remove('selected'));
              }

              document.addEventListener('click', function(e) {
                if (!searchInput.contains(e.target) && !resultsDiv.contains(e.target)) {
                  hideResults();
                }
              });
            }

            // Initialize on DOM ready
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', initAdminAutocomplete);
            } else {
              initAdminAutocomplete();
            }

            setTimeout(initAdminAutocomplete, 100);
          })();
        </script>

      HTML
    end
  end
end
