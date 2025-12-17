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
    # Check for duplicate username
    if data['username'].present? && User.exists?(username: data['username'])
      raise "Username '#{data['username']}' already exists"
    end

    # Check for duplicate email (unless it's a placeholder)
    email = data['email']
    if email.blank?
      email = "temp_#{SecureRandom.hex(8)}@streetwatch.placeholder"
    elsif User.exists?(email: email)
      raise "Email '#{email}' already exists"
    end

    # Create admin-created user profile
    user = User.new(
      username: data['username'],
      name: data['name'],
      email: email,
      password: SecureRandom.hex(16),
      bio: data['bio'],
      profile_type: data['profile_type'] || 'individual',
      admin_created: true
    )
    user.save!
  end

  def import_film(data)
    # Create film with associations
    film = Film.new(
      title: data['title'],
      description: data['description'],
      release_date: parse_date(data['release_date']),
      film_type: data['film_type'] || 'full_length',
      youtube_url: data['youtube_url']
    )

    # Find or create users for filmer/editor
    if data['filmer_username']
      filmer = User.find_by(username: data['filmer_username'])
      film.filmer_user = filmer if filmer
    end

    if data['editor_username']
      editor = User.find_by(username: data['editor_username'])
      film.editor_user = editor if editor
    end

    film.save!

    # Add riders
    if data['rider_usernames']
      usernames = data['rider_usernames'].split(',').map(&:strip)
      usernames.each do |username|
        rider = User.find_by(username: username)
        film.riders << rider if rider && !film.riders.include?(rider)
      end
    end
  end

  def import_photo(data)
    # TODO: Implement photo import logic
    # photo = Photo.create!(...)
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string.to_s) rescue nil
  end
end
