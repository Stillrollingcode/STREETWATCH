ActiveAdmin.register DataImport do
  permit_params :import_type, :file, :column_mapping

  index do
    selectable_column
    id_column
    column :import_type
    column :status
    column :total_rows
    column :successful_rows
    column :failed_rows
    column :admin_user
    column :created_at
    actions
  end

  filter :import_type, as: :select, collection: ['users', 'films', 'photos']
  filter :status, as: :select, collection: ['pending', 'mapping', 'processing', 'completed', 'failed']
  filter :created_at

  show do
    attributes_table do
      row :id
      row :import_type
      row :status
      row :total_rows
      row :successful_rows
      row :failed_rows
      row :admin_user
      row :created_at
      row :updated_at

      row "File" do |import|
        if import.file.attached?
          link_to import.file.filename, rails_blob_path(import.file, disposition: "attachment")
        else
          "No file attached"
        end
      end

      row :column_mapping do |import|
        if import.column_mapping.present?
          simple_format(JSON.pretty_generate(import.column_mapping))
        else
          "Not mapped yet"
        end
      end

      row :error_log do |import|
        simple_format(import.error_log) if import.error_log.present?
      end
    end

    panel "Actions" do
      if data_import.status == 'mapping' && data_import.column_mapping.present?
        button_to "Start Import", process_import_admin_data_import_path(data_import), method: :post, class: "button"
      end
    end
  end

  form html: { multipart: true } do |f|
    f.inputs "Import Details" do
      f.input :import_type, as: :select, collection: ['users', 'films', 'photos'], include_blank: false
      f.input :file, as: :file, hint: "Upload .csv, .xls, or .xlsx file"
    end

    f.actions
  end

  # Custom action to show column mapping interface
  member_action :map_columns, method: :get do
    @data_import = DataImport.find(params[:id])
    @headers = @data_import.extract_headers
    @preview_data = @data_import.preview_data

    # Define available fields based on import type
    @available_fields = case @data_import.import_type
    when 'users'
      ['username', 'name', 'email', 'bio', 'profile_type', 'password']
    when 'films'
      ['title', 'description', 'release_date', 'film_type', 'youtube_url',
       'owner_username', 'company_username', 'filmer_username', 'editor_username', 'rider_usernames']
    when 'photos'
      ['title', 'description', 'photographer_username', 'photo_url']
    else
      []
    end

    render 'admin/data_imports/map_columns', layout: 'active_admin'
  end

  # Custom action to save column mapping
  member_action :save_mapping, method: :post do
    @data_import = DataImport.find(params[:id])
    mapping = params[:mapping] || {}

    # Remove empty mappings
    mapping = mapping.reject { |k, v| v.blank? }

    @data_import.update(
      column_mapping: mapping,
      status: 'mapping'
    )

    redirect_to admin_data_import_path(@data_import), notice: "Column mapping saved! Review and click 'Start Import' to begin."
  end

  # Custom action to process the import
  member_action :process_import, method: :post do
    @data_import = DataImport.find(params[:id])

    if @data_import.column_mapping.blank?
      redirect_to admin_data_import_path(@data_import), alert: "Please map columns first"
      return
    end

    # Process in background (or synchronously for now)
    @data_import.process_import!

    redirect_to admin_data_import_path(@data_import), notice: "Import completed! #{@data_import.successful_rows} successful, #{@data_import.failed_rows} failed."
  end

  controller do
    def create
      @data_import = DataImport.new(permitted_params[:data_import])
      @data_import.admin_user = current_admin_user
      @data_import.status = 'pending'

      if @data_import.save
        redirect_to map_columns_admin_data_import_path(@data_import), notice: "File uploaded! Please map the columns."
      else
        render :new
      end
    end
  end
end
