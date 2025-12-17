# Admin Panel Setup Guide

Your Rails application now has a fully functional admin panel powered by ActiveAdmin with role-based access control.

## Accessing the Admin Panel

### Development
- URL: `http://localhost:3000/admin`
- Default credentials:
  - Email: `admin@example.com`
  - Password: `password`

### Production
You'll need to create a super admin user manually in production:

```bash
rails console
AdminUser.create!(
  email: 'donniekir@gmail.com',
  password: 'Dublin2211!',
  password_confirmation: 'Dublin2211!',
  role: 'super_admin'
)
```

## Admin User Roles

The system supports three role levels:

### 1. Super Admin
- **Full access** to everything
- Can manage other admin users (create, edit, delete)
- Can manage all content (films, users, comments, playlists)
- Can access all admin features

### 2. Admin
- Can manage all content (films, users, comments, playlists)
- **Cannot** manage other admin users
- Can perform all CRUD operations on user content

### 3. Moderator
- Can manage content (films, comments, playlists)
- Can view users but with limited editing capabilities
- Primarily for content moderation

## Features

### Films Management
- Create, edit, and delete films
- Upload videos and thumbnails (stored in AWS S3)
- Add YouTube URLs as video source
- Manage film metadata (title, description, type, company, etc.)
- Assign filmers, editors, and riders
- View film statistics (favorites, comments, playlist inclusions)
- Filter and search films

### User Management
- View all registered users
- Edit user profiles
- Manage user content
- View user activity (films, playlists, comments, favorites)
- Delete user accounts (cascades to their content)
- Upload/change user avatars

### Comments Management
- View all comments across the platform
- Delete inappropriate comments
- View comment threads (parent-child relationships)
- Filter comments by user, film, or date

### Playlists Management
- View all user playlists
- Edit playlist details
- See which films are in each playlist
- Delete playlists

### Admin Users Management (Super Admin Only)
- Create new admin/moderator accounts
- Assign roles to admin users
- Remove admin access

## AWS S3 Integration

All file uploads (videos, thumbnails, avatars) are automatically stored in AWS S3 using Active Storage.

### Configuration
Make sure your AWS credentials are set in Rails credentials:

```bash
rails credentials:edit
```

Add:
```yaml
aws:
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
```

And set environment variables:
```bash
export AWS_REGION=us-east-2
export AWS_BUCKET=your-bucket-name
```

### Storage Configuration
- **Development**: Local disk storage
- **Production**: AWS S3 (configured in [config/storage.yml](config/storage.yml))

## Theme

The admin panel uses the **Arctic Admin** theme, which provides a modern, clean interface with:
- Responsive design
- Dark mode support
- Improved navigation
- Better mobile experience

## Security Features

1. **Authentication**: Devise-based authentication for admin users
2. **Role-based Authorization**: Three-tier access control system
3. **Password Security**: Encrypted passwords using bcrypt
4. **CSRF Protection**: Built-in Rails CSRF protection
5. **Filtered Attributes**: Sensitive fields (passwords) are filtered from logs

## Common Tasks

### Creating a New Admin User
1. Log in as a super admin
2. Navigate to "Admin Users" in the menu
3. Click "New Admin User"
4. Fill in email, password, and select role
5. Click "Create Admin user"

### Managing Films
1. Navigate to "Films" in the menu
2. Use filters to find specific films
3. Click on a film to view details
4. Click "Edit" to modify or "Delete" to remove

### Moderating Comments
1. Navigate to "Comments" in the menu
2. Use filters to find specific comments
3. Click "Delete" to remove inappropriate comments
4. View the film or user associated with the comment

### Viewing User Activity
1. Navigate to "Users" in the menu
2. Click on a user to view their profile
3. Scroll down to see their activity panels:
   - Films they've participated in
   - Their comments
   - Their playlists

## Batch Operations

The admin panel supports batch operations on most resources:
1. Check the boxes next to items you want to modify
2. Select an action from the "Batch Actions" dropdown
3. Confirm the operation

Available batch actions:
- Delete selected items
- Export to CSV

## Troubleshooting

### Cannot Access Admin Panel
- Ensure you've created an admin user (run `rails db:seed` in development)
- Check that you're using the correct credentials
- Verify the admin user exists in the database

### File Uploads Not Working
- Check AWS credentials are correctly configured
- Verify the S3 bucket exists and is accessible
- Check bucket permissions allow uploads
- Review Rails logs for specific error messages

### Permission Denied Errors
- Verify your admin user has the correct role
- Super admin role is required for admin user management
- Check that you're logged in as an admin user, not a regular user

## Production Deployment

Before deploying to production:

1. **Set up AWS S3**:
   - Create an S3 bucket
   - Configure bucket policies for public read access (if needed)
   - Set up IAM user with S3 access

2. **Configure credentials**:
   ```bash
   RAILS_ENV=production rails credentials:edit
   ```

3. **Set environment variables**:
   ```bash
   export AWS_REGION=your-region
   export AWS_BUCKET=your-production-bucket
   ```

4. **Create super admin**:
   ```bash
   RAILS_ENV=production rails console
   AdminUser.create!(email: '...', password: '...', role: 'super_admin')
   ```

5. **Configure Active Storage service**:
   Update [config/environments/production.rb](config/environments/production.rb):
   ```ruby
   config.active_storage.service = :amazon
   ```

## Support

For issues or questions about the admin panel:
- Check the [ActiveAdmin documentation](https://activeadmin.info/)
- Review Rails logs: `tail -f log/development.log`
- Check AWS S3 bucket access and permissions
