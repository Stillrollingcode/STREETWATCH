class ProfileClaimMailer < ApplicationMailer
  default from: 'noreply@streetwatch.com'

  def claim_request(user, message)
    @user = user
    @message = message
    @profile_url = user_url(@user)

    mail(
      to: 'streetwatchmov@gmail.com',
      subject: "Profile Claim Request: #{@user.username}"
    )
  end
end
