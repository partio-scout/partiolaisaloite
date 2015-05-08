module EmailEncrypter

  extend ActiveSupport::Concern

  included do

    attr_encrypted :email,
                   key: AppConfig.email_encryption_key,
                   attribute: "encrypted_email",
                   marshal: true,
                   marshaler: EmailDowncaser

    # = Validations =
    validates_presence_of :email, message: "%{attribute} must be completed"

    validates_format_of :email,
                        with: Authlogic::Regex.email,
                        unless: 'email.blank?',
                        message: "Email '%{value}' not recognised."
    
    # = Finders =
    scope :for_email, ->(email) { where(encrypted_email: encrypt_email(email)) }
    

    # = Methods =
    # NOTE: These methods for the encrypted_email attribute are
    #       defined here to prevent attr_encrypted from defining
    #       it's own attribute accessors using `attr_accessor`
    # TODO: Remove these methods when attr_encrypted is fixed
    def encrypted_email
      super
    end
    
    def encrypted_email=(value)
      super
    end
    
    def encrypted_email?
      super
    end
  end
end
