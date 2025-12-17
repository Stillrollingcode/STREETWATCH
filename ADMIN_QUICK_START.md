# Admin Panel Quick Start

## What Was Installed

Your Rails application now has a complete admin panel with:

✅ **ActiveAdmin** - Professional admin interface
✅ **Arctic Admin Theme** - Modern, responsive design
✅ **Role-Based Access Control** - 3 role levels (super_admin, admin, moderator)
✅ **Full CRUD Operations** - Manage all your content
✅ **AWS S3 Integration** - All uploads go to S3
✅ **PostgreSQL Support** - Works with your production database

## Quick Access

### Login to Admin Panel
```
URL: http://localhost:3000/admin
Email: admin@example.com
Password: password
```

## What You Can Manage

### 📽️ Films
- Add/edit/delete films
- Upload videos and thumbnails to S3
- Link YouTube videos
- Assign filmers, editors, and riders
- View stats (favorites, comments)

### 👥 Users
- View all registered users
- Edit user profiles
- See user activity and content
- Manage user avatars

### 💬 Comments
- View all comments
- Delete inappropriate content
- See comment threads

### 📋 Playlists
- View all user playlists
- Manage playlist content

### 🔐 Admin Users (Super Admin Only)
- Create new admins/moderators
- Assign roles
- Manage admin access

## Admin Roles

| Role | Can Manage Content | Can Manage Users | Can Manage Admins |
|------|-------------------|------------------|-------------------|
| **Super Admin** | ✅ | ✅ | ✅ |
| **Admin** | ✅ | ✅ | ❌ |
| **Moderator** | ✅ | Limited | ❌ |

## Creating Additional Admins

### For Development
Run in Rails console:
```ruby
AdminUser.create!(
  email: 'newadmin@example.com',
  password: 'secure-password',
  password_confirmation: 'secure-password',
  role: 'admin'  # or 'moderator'
)
```

### For Production
```bash
RAILS_ENV=production rails console
# Then run the same command as above
```

## S3 Configuration

Files are automatically uploaded to AWS S3 in production.

### Set Environment Variables
```bash
export AWS_REGION=us-east-2
export AWS_BUCKET=your-bucket-name
```

### Set AWS Credentials
```bash
rails credentials:edit
```

Add:
```yaml
aws:
  access_key_id: YOUR_KEY
  secret_access_key: YOUR_SECRET
```

## Routes

The admin panel is available at:
- Development: `http://localhost:3000/admin`
- Production: `https://yourdomain.com/admin`

Admin routes are automatically mounted at `/admin` and include:
- `/admin` - Dashboard
- `/admin/films` - Films management
- `/admin/users` - Users management
- `/admin/comments` - Comments management
- `/admin/playlists` - Playlists management
- `/admin/admin_users` - Admin users (super admin only)

## File Structure

New files added:
```
app/admin/
  ├── dashboard.rb          # Admin dashboard
  ├── films.rb             # Films admin interface
  ├── users.rb             # Users admin interface
  ├── comments.rb          # Comments admin interface
  ├── playlists.rb         # Playlists admin interface
  ├── admin_users.rb       # Admin users management
  └── favorites.rb         # Favorites management

app/models/
  └── admin_user.rb        # Admin user model with roles

config/initializers/
  └── active_admin.rb      # ActiveAdmin configuration

db/migrate/
  ├── *_devise_create_admin_users.rb
  └── *_create_active_admin_comments.rb
```

## Next Steps

1. **Start Your Server**
   ```bash
   rails server
   ```

2. **Visit Admin Panel**
   Open: `http://localhost:3000/admin`

3. **Login**
   Use: `admin@example.com` / `password`

4. **Create Additional Admins**
   Navigate to "Admin Users" and add team members

5. **Start Managing Content**
   Navigate to Films, Users, Comments, or Playlists

## Security Reminders

⚠️ **Important for Production:**
- Change the default admin password immediately
- Use strong passwords for all admin accounts
- Enable SSL/HTTPS (already configured in production.rb)
- Regularly review admin user access
- Monitor admin activity logs

## Troubleshooting

### Can't login?
- Make sure you ran `rails db:seed` to create the admin user
- Check that you're using the correct email/password
- Try resetting the admin password in Rails console

### Files not uploading?
- Verify AWS credentials are set correctly
- Check S3 bucket exists and is accessible
- Review logs: `tail -f log/development.log`

### Permission errors?
- Only super_admin can manage other admin users
- Verify your role with: `AdminUser.find_by(email: 'your@email.com').role`

## Support

For detailed documentation, see:
- [ADMIN_SETUP.md](ADMIN_SETUP.md) - Complete setup guide
- [ActiveAdmin Docs](https://activeadmin.info/)
- [Arctic Admin Theme](https://github.com/cprodhomme/arctic_admin)
