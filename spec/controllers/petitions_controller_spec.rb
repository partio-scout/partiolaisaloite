require 'rails_helper'

describe PetitionsController do
  describe "new" do

    with_ssl do
      it "should respond to /petitions/new" do
        expect({:get => "/petitions/new"}).to route_to({:controller => "petitions", :action => "new"})
        expect(new_petition_path).to eq '/petitions/new'
      end

      it "should assign a new petition and creator signature" do
        get :new
        expect(assigns[:petition]).not_to be_nil
        expect(assigns[:petition].creator_signature).not_to be_nil
      end

      it "should assign departments" do
        department1 = FactoryGirl.create(:department, :name => 'DFID')
        department2 = FactoryGirl.create(:department, :name => 'Treasury')

        get :new

        expect(assigns[:departments]).to eq [department1, department2]
      end

      it "creator signature should default the country to UK" do
        get :new
        expect(assigns[:petition].creator_signature.country).to eq 'United Kingdom'
      end

      it "should assign @start_on_section to 0" do
        get :new
        expect(assigns[:start_on_section]).to eq 0;
      end

      it "fills in the title if given" do
        title = "my fancy new title"
        get :new, :title => title
        expect(assigns[:petition].title).to eq title
      end
    end
  end

  describe "create" do
    before :each do
      @department = FactoryGirl.create(:department)
      @creator_signature_attributes = {:name => 'John Mcenroe', :email => 'john@example.com', :email_confirmation => 'john@example.com',
                                      :address => 'Rose Cottage', :town => 'London', :postcode => 'SE3 4LL', :country => 'UK', :uk_citizenship => '1', :terms_and_conditions => '1'}
      allow(Captcha).to receive_messages(:verify => true)
    end

    def do_post(options = {})
      post :create, :petition => {:title => 'Save the planet', :description => 'Global warming is upon us', :duration => "12",
        :department_id => @department.id, :creator_signature_attributes => @creator_signature_attributes}.merge(options)
    end

    with_ssl do
      it "should respond to posts to /petitions/new" do
        expect({:post => "/petitions/new"}).to route_to({:controller => "petitions", :action => "create"})
        expect(create_petition_path).to eq('/petitions/new')
      end

      context "valid post" do
        it "should successfully create a new petition and a signature" do
          do_post
          petition = Petition.find_by_title!('Save the planet')
          expect(petition.creator_signature).not_to be_nil
          expect(response).to redirect_to(thank_you_petition_path(petition))
        end

        it "should successfully create a new petition and a signature even when email has white space either end" do
          do_post(:creator_signature_attributes => @creator_signature_attributes.merge(:email => ' john@example.com '))
          petition = Petition.find_by_title!('Save the planet')
        end

        it "should strip a petition title on petition creation" do
          do_post(:title => ' Save the planet')
          petition = Petition.find_by_title!('Save the planet')
        end

        it "should send verification email to petition's creator" do
          email = ActionMailer::Base.deliveries.last
          expect(email.from).to eq(["no-reply@example.gov"])
          expect(email.to).to eq(["john@example.com"])
          expect(email.subject).to match(/Email address confirmation/)
        end

        it "should successfully point the signature at the petition" do
          do_post
          petition = Petition.find_by_title!('Save the planet')
          expect(petition.creator_signature.petition).to eq(petition)
        end

        it "should set user's ip address on signature" do
          do_post
          petition = Petition.find_by_title!('Save the planet')
          expect(petition.creator_signature.ip_address).to eq("0.0.0.0")
        end

        it "should not be able to set the state of a new petition" do
          do_post :state => Petition::VALIDATED_STATE
          petition = Petition.find_by_title!('Save the planet')
          expect(petition.state).to eq(Petition::PENDING_STATE)
        end

        it "should not be able to set the state of a new signature" do
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:state => Signature::VALIDATED_STATE)
          petition = Petition.find_by_title!('Save the planet')
          expect(petition.creator_signature.state).to eq(Signature::PENDING_STATE)
        end

        it "should not set notify_by_email to true on the creator signature" do
          do_post
          expect(Petition.find_by_title!('Save the planet').creator_signature.notify_by_email).to be_truthy
        end
      end

      context "invalid post" do
        it "should not create a new petition if no title is given" do
          do_post :title => ''
          expect(Petition.find_by_title('Save the planet')).to be_nil
          expect(assigns[:petition].errors_on(:title)).not_to be_blank
          expect(response).to be_success
        end

        it "should not create a new petition if email is invalid" do
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:email => 'not much of an email')
          expect(Petition.find_by_title('Save the planet')).to be_nil
          expect(response).to be_success
        end

        it "should not create a new petition if address is blank" do
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:address => '')
          expect(Petition.find_by_title('Save the planet')).to be_nil
          expect(response).to be_success
        end

        it "should not create a new petition if UK citizenship is not confirmed" do
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:uk_citizenship => '0')
          expect(Petition.find_by_title('Save the planet')).to be_nil
          expect(response).to be_success
        end

        it "should assign departments if submission fails" do
          do_post :title => ''
          expect(assigns[:departments]).to eq([@department])
        end

        it "should add an error to @petition if the recaptcha is not valid" do
          allow(Captcha).to receive_messages(:verify => false)
          do_post
          expect(Petition.find_by_title('Save the planet')).to be_nil
          expect(assigns[:petition].creator_signature.errors[:humanity]).to eq(["The captcha was not filled in correctly."])
        end

        it "should assign start_on_section to 0 if there are errors on title, department or description" do
          do_post :title => ''
          expect(assigns[:start_on_section]).to eq(0)
          do_post :department_id => nil
          expect(assigns[:start_on_section]).to eq(0)
          do_post :description => ''
          expect(assigns[:start_on_section]).to eq(0)
        end
        it "should assign start_on_section to 1 if there are errors on name, email, is_uk_citizen, address, town, postcode or country" do
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:name => '')
          expect(assigns[:start_on_section]).to eq(1)
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:email => '')
          expect(assigns[:start_on_section]).to eq(1)
          do_post :is_uk_citizen => '0'
          expect(assigns[:start_on_section]).to eq(1)
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:address => '')
          expect(assigns[:start_on_section]).to eq(1)
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:town => '')
          expect(assigns[:start_on_section]).to eq(1)
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:postcode => '')
          expect(assigns[:start_on_section]).to eq(1)
          do_post :creator_signature_attributes => @creator_signature_attributes.merge(:country => '')
          expect(assigns[:start_on_section]).to eq(1)
        end
        it "should assign start_on_section to 2 if there are errors on recaptcha" do
          allow(Captcha).to receive_messages(:verify => false)
          do_post
          expect(assigns[:start_on_section]).to eq(2)
        end
      end
    end
  end

  describe "show" do
    let(:petition) { double }
    it "assigns the given petition" do
      allow(Petition).to receive_message_chain(:visible, :find => petition)
      get :show, :id => 1
      expect(assigns(:petition)).to eq(petition)
    end

    it "does not allow hidden petitions to be shown" do
      expect {
        allow(Petition).to receive_message_chain(:visible, :find).and_raise ActiveRecord::RecordNotFound
        get :show, :id => 1
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "index" do
    let(:page) { "1" }
    let(:visible) { double.as_null_object }
    before(:each) do
      allow(Petition).to receive_messages(:visible => visible)
    end

    it "Assigns a paginated petition list of the visible petitions" do
      expect(visible).to receive(:paginate).with(:page => page.to_i, :per_page => 20)
      get :index, :page => page
    end

    it "Sanitises the page param" do
      expect(visible).to receive(:paginate).with(:page => 400, :per_page => 20)
      get :index, :page => '400.'
    end


    it "Sets the petition state to 'open'" do
      get :index
      expect(assigns(:petition_search).state).to eq 'open'
    end

    it "Sets state counts to the petition visible state counts" do
      allow(Petition).to receive(:for_state).with('open').and_return(double(:count, :count => 1))
      allow(Petition).to receive(:for_state).with('closed').and_return(double(:count, :count => 2))
      allow(Petition).to receive(:for_state).with('rejected').and_return(double(:count, :count => 4))
      get :index
      expect(assigns(:petition_search).state_counts).to eq({ 'open' => 1, 'closed' => 2, 'rejected' => 4 })
    end

    it "sorting by name sorts alphabetically" do
      expect(SearchOrder).to receive(:sort_order).with(hash_including(:sort => 'title'), anything).and_return(['foo', 'asc'])
      expect(visible).to recieve(:order).with("foo asc")
      get :index, :order => 'asc', :sort => 'title'
    end
  end

  describe "GET #check" do
    it "is successful" do
      get :check
      expect(response).to be_success
    end
  end

  describe "GET #check_results" do
    it_should_behave_like "it searches petitions", :check_results, :search, 10
  end

  describe "POST #resend_confirmation_email" do
    let!(:petition){ FactoryGirl.create(:open_petition) }
    let!(:email) { 'suzie@example.com' }

    before(:each) do
      allow(Petition).to receive_message_chain(:visible, :find).and_return(petition)
    end

    it "finds the petition" do
      expect(Petition.visible).to receive(:find).with(petition.id)
      post :resend_confirmation_email, :id => petition.id, :confirmation_email => email
    end

    it "renders the email resent view" do
      post :resend_confirmation_email, :id => petition.id, :confirmation_email => email
      expect(response).to render_template :resend_confirmation_email
    end

    let(:confirmer) { double }
    it "asks the petition to resend the confirmation email" do
      expect(SignatureConfirmer).to receive(:new).with(petition, email, PetitionMailer, Authlogic::Regex.email).and_return(confirmer)
      expect(confirmer).to receive(:confirm!)
      post :resend_confirmation_email, :id => petition.id, :confirmation_email => email
    end
  end
end
