ActiveAdmin.register Film do
  permit_params :title, :description, :release_date, :custom_filmer_name, :custom_editor_name,
                :company, :company_user_id, :runtime, :music_featured, :film_type, :parent_film_title,
                :filmer_user_id, :editor_user_id, :custom_riders, :aspect_ratio, :youtube_url,
                :thumbnail, :video, :user_id, rider_ids: [], filmer_ids: [], company_ids: []

  # Add "Select All" action across all pages (positioned before other action items)
  action_item :select_all_films, only: :index do
    link_to "Select All #{collection.total_count} Films",
            admin_films_path(params.to_unsafe_h.merge(select_all: 'true')),
            class: 'button',
            style: 'background: #ff9800; color: white;',
            data: { confirm: "This will select all #{collection.total_count} films across all pages. Continue?" }
  end

  # Add "Select All" action across all pages
  batch_action :bulk_edit_all,
               if: proc { params[:select_all].blank? },
               form: -> {
                 {
                   film_type: Film::FILM_TYPES,
                   company: :text,
                   release_date: :datepicker
                 }
               } do |ids, inputs|
    # This handles the actual bulk edit
    films = Film.where(id: ids)

    films.each do |film|
      film.update(film_type: inputs[:film_type]) if inputs[:film_type].present?
      film.update(company: inputs[:company]) if inputs[:company].present?
      film.update(release_date: inputs[:release_date]) if inputs[:release_date].present?
    end

    redirect_to collection_path, notice: "Updated #{films.count} films"
  end

  # Add custom action item for search bar
  action_item :search, only: :index do
    text_node %{
      <div style="display: flex; align-items: center; margin-top: 15px;">
        <form action="#{admin_films_path}" method="get" accept-charset="UTF-8" style="display: flex; gap: 8px; align-items: center;">
          <input
            name="q[title_or_description_or_company_or_friendly_id_or_filmer_user_username_or_editor_user_username_or_riders_username_or_filmers_username_or_companies_username_cont]"
            type="text"
            placeholder="Search films (title, ID, tagged users)..."
            value="#{params.dig(:q, :title_or_description_or_company_or_friendly_id_or_filmer_user_username_or_editor_user_username_or_riders_username_or_filmers_username_or_companies_username_cont)}"
            style="width: 350px; padding: 6px 12px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px;" />
          <input type="submit" value="Search" style="padding: 6px 16px; background: #5E6469; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 13px; white-space: nowrap;" />
          #{params[:q].present? ? '<a href="' + admin_films_path + '" style="padding: 6px 16px; background: #999; color: white; text-decoration: none; border-radius: 4px; display: inline-block; font-size: 13px; white-space: nowrap;">Clear</a>' : ''}
        </form>
      </div>
    }.html_safe
  end

  index do
    selectable_column
    column "ID", :friendly_id
    column :title
    column :film_type
    column :company
    column :release_date
    column "Filmer" do |film|
      film.filmer_display_name
    end
    column "Editor" do |film|
      film.editor_display_name
    end
    column :runtime
    column "Video" do |film|
      film.has_video? ? status_tag("yes", class: "ok") : status_tag("no")
    end
    column :created_at
    actions
  end

  controller do
    after_action :add_select_all_script, only: :index

    def find_resource
      Film.find_by_friendly_or_id(params[:id])
    end

    def scoped_collection
      # Only load associations needed for the index page to avoid N+1 queries
      # Distinct is applied at the query level to prevent duplicates from joins
      super.includes(:filmer_user, :editor_user, :video_attachment).distinct
    end

    def index
      super do |format|
        format.html do
          if params[:select_all] == 'true'
            # Get all film IDs matching current filters
            @all_film_ids = @films.pluck(:id)
          end
        end
        format.json do
          films = @films.limit(params[:per_page] || 20).map do |film|
            {
              id: film.id,
              title: film.title,
              release_date: film.release_date,
              film_type: film.film_type
            }
          end
          render json: films
        end
      end
    end

    def add_select_all_script
      return unless @all_film_ids.present?

      response.body = response.body.sub(
        '</body>',
        <<~HTML + '</body>'
          <script type="text/javascript">
            (function() {
              const allIds = #{@all_film_ids.to_json};
              console.log('[SELECT ALL] Script loaded with', allIds.length, 'film IDs');

              function selectAllFilms() {
                console.log('[SELECT ALL] Running selectAllFilms function');

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
                notice.textContent = 'Selected all ' + allIds.length + ' films across all pages. Choose a batch action from the dropdown.';
                notice.style.cssText = 'position: fixed; top: 20px; left: 50%; transform: translateX(-50%); z-index: 10000; padding: 15px 30px; background: #6dd27f; color: white; border-radius: 4px; box-shadow: 0 2px 10px rgba(0,0,0,0.2);';
                document.body.appendChild(notice);

                setTimeout(function() {
                  notice.remove();
                }, 5000);
              }

              // Try multiple times to ensure DOM is ready
              setTimeout(selectAllFilms, 100);
              setTimeout(selectAllFilms, 500);
              setTimeout(selectAllFilms, 1000);
            })();
          </script>
        HTML
      )
    end
  end

  # Search bar - searches across title, description, friendly_id, company, and all associated users
  filter :title_or_description_or_company_or_friendly_id_or_filmer_user_username_or_editor_user_username_or_riders_username_or_filmers_username_or_companies_username_cont,
         as: :string,
         label: 'Search (title, ID, tagged users)'

  filter :title
  filter :film_type, as: :select, collection: Film::FILM_TYPES
  filter :company
  filter :release_date
  filter :filmer_user, collection: -> { User.order(:username) }
  filter :editor_user, collection: -> { User.order(:username) }
  filter :created_at

  show do
    attributes_table do
      row :friendly_id
      row "Database ID", :id
      row :title
      row :description
      row :film_type

      row "Companies" do |film|
        company_links = film.companies.map { |c| link_to c.username, admin_user_path(c) }
        company_links << link_to(film.company_user.username, admin_user_path(film.company_user)) if film.company_user
        company_links << film.company if film.company.present?
        company_links.any? ? company_links.join(", ").html_safe : status_tag("empty", class: "warning")
      end

      row :release_date
      row :runtime
      row :aspect_ratio
      row :parent_film_title

      row "Filmers" do |film|
        filmer_links = film.filmers.map { |f| link_to f.username, admin_user_path(f) }
        filmer_links << link_to(film.filmer_user.username, admin_user_path(film.filmer_user)) if film.filmer_user
        filmer_links << film.custom_filmer_name if film.custom_filmer_name.present?
        filmer_links.any? ? filmer_links.join(", ").html_safe : status_tag("empty", class: "warning")
      end

      row "Editor" do |film|
        if film.editor_user
          link_to film.editor_user.username, admin_user_path(film.editor_user)
        else
          film.custom_editor_name
        end
      end

      row "Riders" do |film|
        film.riders.map { |r| link_to r.username, admin_user_path(r) }.join(", ").html_safe
      end

      row :custom_riders

      row "Video URL" do |film|
        if film.youtube_url.present?
          platform_name = film.video_platform == :vimeo ? "Vimeo" : "YouTube"
          link_to "#{platform_name}: #{film.youtube_url}", film.youtube_url, target: "_blank"
        end
      end

      row "Thumbnail" do |film|
        if film.thumbnail.attached?
          image_tag url_for(film.thumbnail), style: "max-width: 400px;"
        elsif film.youtube_thumbnail_url
          image_tag film.youtube_thumbnail_url, style: "max-width: 400px;"
        end
      end

      row "Video" do |film|
        if film.video.attached?
          link_to "Download Video", rails_blob_path(film.video, disposition: "attachment")
        end
      end

      row :music_featured
      row :created_at
      row :updated_at
    end

    panel "Stats" do
      attributes_table_for film do
        row "Favorites" do
          film.favorites.count
        end
        row "Comments" do
          film.comments.count
        end
        row "In Playlists" do
          film.playlists.count
        end
      end
    end

    panel "Approval Status" do
      if film.film_approvals.any?
        table_for film.film_approvals do
          column "Approver" do |approval|
            link_to approval.approver.username, admin_user_path(approval.approver)
          end
          column "Role" do |approval|
            approval.approval_type.titleize
          end
          column "Status" do |approval|
            case approval.status
            when 'approved'
              status_tag("Approved", class: "ok")
            when 'rejected'
              status_tag("Rejected", class: "error")
            else
              status_tag("Pending", class: "warning")
            end
          end
          column "Date" do |approval|
            if approval.status == 'pending'
              "Requested #{time_ago_in_words(approval.created_at)} ago"
            else
              "#{approval.status.titleize} #{time_ago_in_words(approval.updated_at)} ago"
            end
          end
        end
      else
        para "No profile approvals required for this film.", style: "color: #999; padding: 20px; text-align: center;"
      end

      if film.published?
        para "✓ This film is published and visible to the public.", style: "color: #6dd27f; padding: 20px; text-align: center; font-weight: bold;"
      else
        para "⏳ This film is pending approval and not yet visible to the public.", style: "color: #ff9800; padding: 20px; text-align: center; font-weight: bold;"
      end
    end
  end

  form html: { multipart: true } do |f|
    f.inputs "Film Details" do
      f.input :title
      f.input :description, as: :text
      f.input :film_type, as: :select, collection: Film::FILM_TYPES

      # Owner/Uploader autocomplete
      li class: 'input' do
        text_node %{
          <label class="label">Owner/Uploader</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="owner-search-input" placeholder="Search for user..." value="#{f.object.user&.username}" autocomplete="off" />
            <div class="autocomplete-results" id="owner-results"></div>
            <input type="hidden" name="film[user_id]" id="film_user_id" value="#{f.object.user_id}" />
          </div>
          <p class="inline-hints">The user who owns/uploaded this film</p>
        }.html_safe
      end

      # Companies multi-select autocomplete
      li class: 'input' do
        text_node %{
          <label class="label">Companies</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="companies-search-input" placeholder="Search for companies..." autocomplete="off" />
            <div class="autocomplete-results" id="companies-results"></div>
          </div>
          <div id="selected-companies-list" class="selected-riders-list"></div>
          <div id="companies-hidden-fields"></div>
          <p class="inline-hints">Search and select registered company profiles</p>
        }.html_safe
      end

      f.input :company, hint: "Custom company names (comma-separated) for non-registered companies"
      f.input :release_date, as: :datepicker
      f.input :runtime, hint: "Runtime in minutes"
      f.input :aspect_ratio, hint: "e.g., 16:9, 4:3, 21:9"
      f.input :parent_film_title, hint: "For video parts or series"
    end

    f.inputs "Credits" do
      # Filmers multi-select autocomplete
      li class: 'input' do
        text_node %{
          <label class="label">Filmers</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="filmers-search-input" placeholder="Search for filmers..." autocomplete="off" />
            <div class="autocomplete-results" id="filmers-results"></div>
          </div>
          <div id="selected-filmers-list" class="selected-riders-list"></div>
          <div id="filmers-hidden-fields"></div>
          <p class="inline-hints">Search and select registered user profiles</p>
        }.html_safe
      end

      f.input :custom_filmer_name, hint: "Custom filmer names (comma-separated) for non-registered filmers"

      # Editor autocomplete
      li class: 'input' do
        text_node %{
          <label class="label">Editor</label>
          <div class="autocomplete-wrapper">
            <input type="text" class="autocomplete-input" id="editor-search-input" placeholder="Search for editor..." value="#{f.object.editor_display_name}" autocomplete="off" />
            <div class="autocomplete-results" id="editor-results"></div>
            <input type="hidden" name="film[editor_user_id]" id="film_editor_user_id" value="#{f.object.editor_user_id}" />
          </div>
          <p class="inline-hints">Select a user or use custom name below</p>
        }.html_safe
      end

      f.input :custom_editor_name, hint: "Only if editor is not a registered user"

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

      f.input :custom_riders, as: :text, hint: "One rider name per line for non-registered riders"
    end

    f.inputs "Media" do
      f.input :youtube_url, label: "Video URL (YouTube or Vimeo)", hint: "Enter YouTube or Vimeo video URL"
      f.input :thumbnail, as: :file, hint: "Upload custom thumbnail image (auto-downloaded from video platform if not provided)"
      f.input :video, as: :file, hint: "Upload video file (will be stored in S3) - TEMPORARILY DISABLED for legal compliance"
    end

    f.inputs "Additional Info" do
      f.input :music_featured, as: :text, hint: "Songs/artists featured in the film"
    end

    f.actions

    # Embed data and JavaScript together
    li style: 'display:none;' do
      rider_ids = f.object.rider_ids rescue []
      filmer_ids = f.object.filmer_ids rescue []
      company_ids = f.object.company_ids rescue []

      # Load existing users for display, but don't load all users
      existing_riders = f.object.riders.select(:id, :username) rescue []
      existing_filmers = f.object.filmers.select(:id, :username) rescue []
      existing_companies = f.object.companies.select(:id, :username) rescue []
      existing_owner = f.object.user ? { id: f.object.user.id, username: f.object.user.username } : nil
      existing_editor = f.object.editor_user ? { id: f.object.editor_user.id, username: f.object.editor_user.username } : nil

      film_data = {
        existingRiderIds: rider_ids,
        existingFilmerIds: filmer_ids,
        existingCompanyIds: company_ids,
        existingRiders: existing_riders.map { |u| { id: u.id, username: u.username } },
        existingFilmers: existing_filmers.map { |u| { id: u.id, username: u.username } },
        existingCompanies: existing_companies.map { |u| { id: u.id, username: u.username } },
        existingOwner: existing_owner,
        existingEditor: existing_editor
      }

      text_node <<~HTML.html_safe
        <script type='text/javascript'>window.filmFormData = #{film_data.to_json};</script>
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

            console.log('Admin autocomplete script loaded');
            console.log('Film form data:', window.filmFormData);

            function initAdminAutocomplete() {
              if (initialized) {
                console.log('Already initialized, skipping');
                return;
              }
              initialized = true;
              console.log('Initializing admin autocomplete...');

              // Initialize single-select autocomplete for owner and editor
              initSingleAutocomplete('owner', 'film_user_id');
              initSingleAutocomplete('editor', 'film_editor_user_id');

              // Initialize multi-select autocomplete for riders, filmers, and companies
              initRidersAutocomplete();
              initFilmersAutocomplete();
              initCompaniesAutocomplete();
            }

            function initSingleAutocomplete(fieldName, hiddenFieldId) {
              const input = document.getElementById(fieldName + '-search-input');
              const resultsDiv = document.getElementById(fieldName + '-results');
              const hiddenField = document.getElementById(hiddenFieldId);

              console.log(`Initializing ${fieldName} autocomplete:`, {
                input: !!input,
                resultsDiv: !!resultsDiv,
                hiddenField: !!hiddenField
              });

              if (!input || !resultsDiv || !hiddenField) {
                console.warn(`Missing elements for ${fieldName} autocomplete`);
                return;
              }

              let currentFocus = -1;
              let searchTimer;

              // Show results on focus
              input.addEventListener('focus', function() {
                if (this.value.trim().length >= 2) {
                  showResults(this.value);
                }
              });

              // Filter as user types
              input.addEventListener('input', function() {
                const value = this.value.trim();
                console.log(`${fieldName} input changed:`, value);

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

              // Keyboard navigation
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

                // Fetch users via AJAX
                const url = '/admin/users.json?q[username_cont]=' + encodeURIComponent(searchTerm) + '&per_page=10';
                console.log(`${fieldName} autocomplete: Fetching ${url}`);

                fetch(url)
                  .then(res => {
                    console.log(`${fieldName} autocomplete: Response status ${res.status}`);
                    if (!res.ok) {
                      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
                    }
                    return res.json();
                  })
                  .then(data => {
                    console.log(`${fieldName} autocomplete: Received ${data.length} results`, data);

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

              // Close results when clicking outside
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

              console.log('Initializing riders autocomplete:', {
                searchInput: !!searchInput,
                resultsDiv: !!resultsDiv,
                selectedList: !!selectedList,
                hiddenFieldsContainer: !!hiddenFieldsContainer
              });

              if (!searchInput || !resultsDiv || !selectedList) {
                console.warn('Missing elements for riders autocomplete');
                return;
              }

              const selectedRiders = new Map();
              let currentFocus = -1;
              let searchTimer;

              // Load existing riders from window object
              const existingRiders = window.filmFormData?.existingRiders || [];
              console.log('Existing riders:', existingRiders);
              if (existingRiders && existingRiders.length > 0) {
                existingRiders.forEach(rider => {
                  selectedRiders.set(rider.id, rider);
                  console.log('Added existing rider:', rider.username);
                });
                renderSelectedRiders();
              }

              // Show results on focus
              searchInput.addEventListener('focus', function() {
                if (this.value.trim().length > 0) {
                  showResults(this.value);
                }
              });

              // Filter as user types
              searchInput.addEventListener('input', function() {
                const value = this.value.trim();
                console.log('Riders input changed:', value);

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

              // Keyboard navigation
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
                // Update visual list
                selectedList.innerHTML = '';
                selectedRiders.forEach((rider, id) => {
                  const tag = document.createElement('div');
                  tag.className = 'selected-rider-tag';
                  tag.innerHTML = '<span>' + rider.username + '</span><button type="button" class="remove-rider-btn" data-rider-id="' + id + '">×</button>';
                  selectedList.appendChild(tag);
                });

                // Update hidden fields
                hiddenFieldsContainer.innerHTML = '';
                selectedRiders.forEach((rider, id) => {
                  const input = document.createElement('input');
                  input.type = 'hidden';
                  input.name = 'film[rider_ids][]';
                  input.value = id;
                  hiddenFieldsContainer.appendChild(input);
                });

                // Add event listeners to remove buttons
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

              // Close results when clicking outside
              document.addEventListener('click', function(e) {
                if (!searchInput.contains(e.target) && !resultsDiv.contains(e.target)) {
                  hideResults();
                }
              });
            }

            function initFilmersAutocomplete() {
              const searchInput = document.getElementById('filmers-search-input');
              const resultsDiv = document.getElementById('filmers-results');
              const selectedList = document.getElementById('selected-filmers-list');
              const hiddenFieldsContainer = document.getElementById('filmers-hidden-fields');

              if (!searchInput || !resultsDiv || !selectedList) {
                console.warn('Missing elements for filmers autocomplete');
                return;
              }

              const selectedFilmers = new Map();
              let currentFocus = -1;
              let searchTimer;

              // Load existing filmers from window object
              const existingFilmers = window.filmFormData?.existingFilmers || [];
              if (existingFilmers && existingFilmers.length > 0) {
                existingFilmers.forEach(filmer => {
                  selectedFilmers.set(filmer.id, filmer);
                });
                renderSelectedFilmers();
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
                    const filtered = data.filter(u => !selectedFilmers.has(u.id));

                    resultsDiv.innerHTML = '';
                    currentFocus = -1;
                    if (filtered.length === 0) {
                      resultsDiv.innerHTML = '<div class="autocomplete-item no-results">No filmers found</div>';
                    } else {
                      filtered.forEach(user => {
                        const div = document.createElement('div');
                        div.className = 'autocomplete-item';
                        div.textContent = user.username;
                        div.addEventListener('click', function() {
                          addFilmer(user);
                        });
                        resultsDiv.appendChild(div);
                      });
                    }
                    resultsDiv.classList.add('show');
                  })
                  .catch(err => {
                    console.error('Filmers autocomplete error:', err);
                    resultsDiv.innerHTML = '<div class="autocomplete-item no-results">Error loading users</div>';
                  });
              }

              function hideResults() {
                resultsDiv.classList.remove('show');
                currentFocus = -1;
              }

              function addFilmer(filmer) {
                selectedFilmers.set(filmer.id, filmer);
                renderSelectedFilmers();
                searchInput.value = '';
                hideResults();
                searchInput.focus();
              }

              function removeFilmer(filmerId) {
                selectedFilmers.delete(filmerId);
                renderSelectedFilmers();
              }

              function renderSelectedFilmers() {
                selectedList.innerHTML = '';
                selectedFilmers.forEach((filmer, id) => {
                  const tag = document.createElement('div');
                  tag.className = 'selected-rider-tag';
                  tag.innerHTML = '<span>' + filmer.username + '</span><button type="button" class="remove-filmer-btn" data-filmer-id="' + id + '">×</button>';
                  selectedList.appendChild(tag);
                });

                hiddenFieldsContainer.innerHTML = '';
                selectedFilmers.forEach((filmer, id) => {
                  const input = document.createElement('input');
                  input.type = 'hidden';
                  input.name = 'film[filmer_ids][]';
                  input.value = id;
                  hiddenFieldsContainer.appendChild(input);
                });

                selectedList.querySelectorAll('.remove-filmer-btn').forEach(btn => {
                  btn.addEventListener('click', function() {
                    const filmerId = parseInt(this.getAttribute('data-filmer-id'));
                    removeFilmer(filmerId);
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

            function initCompaniesAutocomplete() {
              const searchInput = document.getElementById('companies-search-input');
              const resultsDiv = document.getElementById('companies-results');
              const selectedList = document.getElementById('selected-companies-list');
              const hiddenFieldsContainer = document.getElementById('companies-hidden-fields');

              if (!searchInput || !resultsDiv || !selectedList) {
                console.warn('Missing elements for companies autocomplete');
                return;
              }

              const selectedCompanies = new Map();
              let currentFocus = -1;
              let searchTimer;

              // Load existing companies from window object
              const existingCompanies = window.filmFormData?.existingCompanies || [];
              if (existingCompanies && existingCompanies.length > 0) {
                existingCompanies.forEach(company => {
                  selectedCompanies.set(company.id, company);
                });
                renderSelectedCompanies();
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

                // Filter for company profile types only
                fetch('/admin/users.json?q[username_cont]=' + encodeURIComponent(searchTerm) + '&q[profile_type_eq]=company&per_page=10')
                  .then(res => res.json())
                  .then(data => {
                    const filtered = data.filter(u => !selectedCompanies.has(u.id));

                    resultsDiv.innerHTML = '';
                    currentFocus = -1;
                    if (filtered.length === 0) {
                      resultsDiv.innerHTML = '<div class="autocomplete-item no-results">No companies found</div>';
                    } else {
                      filtered.forEach(user => {
                        const div = document.createElement('div');
                        div.className = 'autocomplete-item';
                        div.textContent = user.username;
                        div.addEventListener('click', function() {
                          addCompany(user);
                        });
                        resultsDiv.appendChild(div);
                      });
                    }
                    resultsDiv.classList.add('show');
                  })
                  .catch(err => {
                    console.error('Companies autocomplete error:', err);
                    resultsDiv.innerHTML = '<div class="autocomplete-item no-results">Error loading companies</div>';
                  });
              }

              function hideResults() {
                resultsDiv.classList.remove('show');
                currentFocus = -1;
              }

              function addCompany(company) {
                selectedCompanies.set(company.id, company);
                renderSelectedCompanies();
                searchInput.value = '';
                hideResults();
                searchInput.focus();
              }

              function removeCompany(companyId) {
                selectedCompanies.delete(companyId);
                renderSelectedCompanies();
              }

              function renderSelectedCompanies() {
                selectedList.innerHTML = '';
                selectedCompanies.forEach((company, id) => {
                  const tag = document.createElement('div');
                  tag.className = 'selected-rider-tag';
                  tag.innerHTML = '<span>' + company.username + '</span><button type="button" class="remove-company-btn" data-company-id="' + id + '">×</button>';
                  selectedList.appendChild(tag);
                });

                hiddenFieldsContainer.innerHTML = '';
                selectedCompanies.forEach((company, id) => {
                  const input = document.createElement('input');
                  input.type = 'hidden';
                  input.name = 'film[company_ids][]';
                  input.value = id;
                  hiddenFieldsContainer.appendChild(input);
                });

                selectedList.querySelectorAll('.remove-company-btn').forEach(btn => {
                  btn.addEventListener('click', function() {
                    const companyId = parseInt(this.getAttribute('data-company-id'));
                    removeCompany(companyId);
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

            // Also try to initialize after a short delay (for ActiveAdmin quirks)
            setTimeout(initAdminAutocomplete, 100);
          })();
        </script>

      HTML
    end
  end
end
