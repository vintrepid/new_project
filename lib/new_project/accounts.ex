defmodule NewProject.Accounts do
  use Ash.Domain, otp_app: :new_project, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource NewProject.Accounts.Token
    resource NewProject.Accounts.User
  end
end
