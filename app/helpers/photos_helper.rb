module PhotosHelper
  # All photos display at natural aspect ratio
  # No metadata check - let browser handle aspect ratio from image itself
  def photo_display_class(photo)
    "photo-thumbnail-natural"
  end

  # No inline style needed - CSS handles everything
  def photo_natural_style(photo)
    ""
  end
end
