class DataImport < ApplicationRecord
  has_one_attached :file
  belongs_to :admin_user

  validates :import_type, presence: true, inclusion: { in: %w[users films photos] }
  validates :status, presence: true, inclusion: { in: %w[pending mapping processing completed failed] }

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "error_log", "failed_rows", "id", "import_type", "status",
     "successful_rows", "total_rows", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["admin_user"]
  end

  # Get column headers from uploaded file
  def extract_headers
    return [] unless file.attached?

    spreadsheet = open_spreadsheet
    spreadsheet.row(1) # First row contains headers
  end

  # Get preview data (first 5 rows)
  def preview_data
    return [] unless file.attached?

    spreadsheet = open_spreadsheet
    (2..6).map { |i| spreadsheet.row(i) }.compact
  end

  # Import data based on column mapping
  def process_import!
    update(status: 'processing')

    spreadsheet = open_spreadsheet
    headers = spreadsheet.row(1)
    errors = []
    successful = 0
    failed = 0

    (2..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      row_data = map_row_to_attributes(headers, row)

      begin
        case import_type
        when 'users'
          import_user(row_data)
        when 'films'
          import_film(row_data)
        when 'photos'
          import_photo(row_data)
        end
        successful += 1
      rescue => e
        failed += 1
        errors << "Row #{i}: #{e.message}"
      end
    end

    update(
      status: failed > 0 ? 'completed' : 'completed',
      total_rows: spreadsheet.last_row - 1,
      successful_rows: successful,
      failed_rows: failed,
      error_log: errors.join("\n")
    )
  end

  private

  def open_spreadsheet
    # Download file to a temporary path for Roo to read
    tempfile = Tempfile.new([file.filename.base, file.filename.extension_with_delimiter])
    tempfile.binmode
    file.download { |chunk| tempfile.write(chunk) }
    tempfile.rewind

    case File.extname(file.filename.to_s)
    when '.csv'
      Roo::CSV.new(tempfile.path)
    when '.xls'
      Roo::Excel.new(tempfile.path)
    when '.xlsx'
      Roo::Excelx.new(tempfile.path)
    else
      raise "Unknown file type: #{file.filename}"
    end
  ensure
    tempfile&.close
  end

  def map_row_to_attributes(headers, row)
    mapped = {}
    column_mapping.each do |excel_col, model_attr|
      col_index = headers.index(excel_col)
      mapped[model_attr] = row[col_index] if col_index
    end
    mapped
  end

  def import_user(data)
    # Skip if duplicate username exists
    if data['username'].present? && User.exists?(username: data['username'])
      raise "Skipped: Username '#{data['username']}' already exists"
    end

    # Check for duplicate email (unless it's a placeholder)
    email = data['email']
    if email.blank?
      email = "temp_#{SecureRandom.hex(8)}@streetwatch.placeholder"
    elsif User.exists?(email: email)
      raise "Skipped: Email '#{email}' already exists"
    end

    # Create admin-created user profile
    password = data['password'].presence || SecureRandom.hex(12)
    profile_type = data['profile_type'].to_s.downcase
    profile_type = 'individual' unless ['individual', 'company', 'crew'].include?(profile_type)
    user = User.new(
      username: data['username'],
      name: data['name'],
      email: email,
      password: password,
      password_confirmation: password,
      bio: data['bio'],
      profile_type: profile_type,
      admin_created: true,
      confirmed_at: Time.current
    )
    user.save!
  end

  def import_film(data)
    # Check if film already exists - if so, update tags instead of skipping
    existing_film = Film.find_by(title: data['title']) if data['title'].present?
    is_update = existing_film.present?

    # Skip the automatic approval callback for bulk imports - we'll create approvals manually
    Film.skip_callback(:commit, :after, :create_approval_requests)

    begin
      if is_update
        # Update existing film with new tags
        film = existing_film
        Rails.logger.info "[IMPORT] Film '#{film.title}' already exists - updating tags"
      else
        # Create new film with associations
        film = Film.new(
          title: data['title'],
          description: data['description'],
          release_date: parse_date(data['release_date']),
          film_type: data['film_type'] || 'full_length',
          youtube_url: data['youtube_url']
        )

        # Find owner/uploader by username (only for new films)
        if data['owner_username']
          owner = User.find_by(username: data['owner_username'])
          film.user = owner if owner
        end

        # Handle legacy single company (backwards compatibility, only for new films)
        # Includes both 'company' and 'crew' profile types
        if data['company_username']
          company = User.find_by(username: data['company_username'], profile_type: ['company', 'crew'])
          film.company_user = company if company
        end

        # Handle legacy single filmer (backwards compatibility, only for new films)
        if data['filmer_username']
          filmer = User.find_by(username: data['filmer_username'])
          film.filmer_user = filmer if filmer
        end

        film.save!
      end

      # Update editor (for both new and existing films)
      if data['editor_username']
        editor = User.find_by(username: data['editor_username'])
        if editor && film.editor_user != editor
          film.update(editor_user: editor)
          Rails.logger.info "[IMPORT] #{is_update ? 'Updated' : 'Set'} editor for film '#{film.title}' to '#{editor.username}'"
        end
      end

      # Add filmers (multiple, comma-separated)
      if data['filmer_usernames']
        usernames = data['filmer_usernames'].split(',').map(&:strip)
        Rails.logger.info "[IMPORT] Film '#{film.title}' - Processing #{usernames.count} filmers: #{usernames.inspect}"

        usernames.each do |username|
          next if username.blank? # Skip empty strings

          filmer = User.find_by(username: username)
          if filmer
            if !film.filmers.include?(filmer)
              film.filmers << filmer
              Rails.logger.info "[IMPORT] Added filmer '#{username}' to film '#{film.title}'"
            else
              Rails.logger.info "[IMPORT] Filmer '#{username}' already associated with film '#{film.title}'"
            end
          else
            Rails.logger.warn "[IMPORT] Filmer user '#{username}' not found"
          end
        end
      end

      # Add companies (multiple, comma-separated) - includes both 'company' and 'crew' profile types
      if data['company_usernames']
        usernames = data['company_usernames'].split(',').map(&:strip)
        Rails.logger.info "[IMPORT] Film '#{film.title}' - Processing #{usernames.count} companies/crews: #{usernames.inspect}"

        usernames.each do |username|
          next if username.blank? # Skip empty strings

          company = User.find_by(username: username, profile_type: ['company', 'crew'])
          if company
            if !film.companies.include?(company)
              film.companies << company
              Rails.logger.info "[IMPORT] Added company/crew '#{username}' to film '#{film.title}'"
            else
              Rails.logger.info "[IMPORT] Company/crew '#{username}' already associated with film '#{film.title}'"
            end
          else
            Rails.logger.warn "[IMPORT] Company/crew user '#{username}' not found or not a company/crew profile"
          end
        end
      end

      # Add riders (multiple, comma-separated)
      if data['rider_usernames']
        usernames = data['rider_usernames'].split(',').map(&:strip)
        Rails.logger.info "[IMPORT] Film '#{film.title}' - Processing #{usernames.count} riders: #{usernames.inspect}"

        usernames.each do |username|
          next if username.blank? # Skip empty strings

          rider = User.find_by(username: username)
          if rider
            if !film.riders.include?(rider)
              film.riders << rider
              Rails.logger.info "[IMPORT] Added rider '#{username}' to film '#{film.title}'"
            else
              Rails.logger.info "[IMPORT] Rider '#{username}' already associated with film '#{film.title}'"
            end
          else
            Rails.logger.warn "[IMPORT] Rider user '#{username}' not found"
          end
        end
      end

      # Auto-approve all tags for bulk imports
      film.riders.each do |rider|
        approval = FilmApproval.find_or_initialize_by(film: film, approver: rider, approval_type: 'rider')
        approval.status = 'approved'
        approval.save!
      end

      film.filmers.each do |filmer|
        approval = FilmApproval.find_or_initialize_by(film: film, approver: filmer, approval_type: 'filmer')
        approval.status = 'approved'
        approval.save!
      end

      film.companies.each do |company|
        approval = FilmApproval.find_or_initialize_by(film: film, approver: company, approval_type: 'company')
        approval.status = 'approved'
        approval.save!
      end

      if film.editor_user
        approval = FilmApproval.find_or_initialize_by(film: film, approver: film.editor_user, approval_type: 'editor')
        approval.status = 'approved'
        approval.save!
      end

      Rails.logger.info "[IMPORT] Auto-approved all tags for film '#{film.title}'"
    ensure
      # Always re-enable the callback after import
      Film.set_callback(:commit, :after, :create_approval_requests)
    end
  end

  def import_photo(data)
    # Skip if duplicate title exists in the same album
    album = Album.find_by(id: data['album_id']) || Album.find_by(title: data['album_title'])

    if !album
      raise "Album not found with ID '#{data['album_id']}' or title '#{data['album_title']}'"
    end

    if data['title'].present? && Photo.exists?(title: data['title'], album: album)
      raise "Skipped: Photo with title '#{data['title']}' already exists in this album"
    end

    # Skip the automatic approval callback for bulk imports - we'll create approvals manually
    Photo.skip_callback(:create, :after, :create_approval_requests)

    begin
      # Find owner/uploader by username
      uploader = nil
      if data['uploader_username']
        uploader = User.find_by(username: data['uploader_username'])
        raise "Uploader user '#{data['uploader_username']}' not found" unless uploader
      else
        raise "Uploader username is required"
      end

      # Create photo with basic attributes
      photo = Photo.new(
        album: album,
        user: uploader,
        title: data['title'],
        description: data['description'],
        date_taken: parse_date(data['date_taken']),
        custom_photographer_name: data['custom_photographer_name'],
        custom_riders: data['custom_riders']
      )

      # Find photographer by username
      if data['photographer_username']
        photographer = User.find_by(username: data['photographer_username'])
        photo.photographer_user = photographer if photographer
      end

      # Find company by username
      if data['company_username']
        company = User.find_by(username: data['company_username'], profile_type: 'company')
        photo.company_user = company if company
      end

      # Note: Photo requires an image on create, so we'll skip validation for imports
      # You'll need to attach images separately after import
      photo.save!(validate: false)

      # Add riders (multiple, comma-separated)
      if data['rider_usernames']
        usernames = data['rider_usernames'].split(',').map(&:strip)
        Rails.logger.info "[IMPORT] Photo '#{photo.title}' - Processing #{usernames.count} riders: #{usernames.inspect}"

        usernames.each do |username|
          next if username.blank?

          rider = User.find_by(username: username)
          if rider
            if !photo.riders.include?(rider)
              photo.riders << rider
              Rails.logger.info "[IMPORT] Added rider '#{username}' to photo '#{photo.title}'"
            else
              Rails.logger.info "[IMPORT] Rider '#{username}' already associated with photo '#{photo.title}'"
            end
          else
            Rails.logger.warn "[IMPORT] Rider user '#{username}' not found"
          end
        end
      end

      # Auto-approve all tags for bulk imports
      photo.riders.each do |rider|
        approval = PhotoApproval.find_or_initialize_by(photo: photo, approver: rider, approval_type: 'rider')
        approval.status = 'approved'
        approval.save!
      end

      if photo.photographer_user && photo.photographer_user_id != photo.user_id
        approval = PhotoApproval.find_or_initialize_by(photo: photo, approver: photo.photographer_user, approval_type: 'photographer')
        approval.status = 'approved'
        approval.save!
      end

      if photo.company_user
        approval = PhotoApproval.find_or_initialize_by(photo: photo, approver: photo.company_user, approval_type: 'company')
        approval.status = 'approved'
        approval.save!
      end

      Rails.logger.info "[IMPORT] Auto-approved all tags for photo '#{photo.title}'"
    ensure
      # Always re-enable the callback after import
      Photo.set_callback(:create, :after, :create_approval_requests)
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string.to_s) rescue nil
  end
end
