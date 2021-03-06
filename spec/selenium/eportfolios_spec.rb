require File.expand_path(File.dirname(__FILE__) + '/common')

describe "eportfolios" do
  it_should_behave_like "in-process server selenium tests"

  def create_eportfolio(is_public = false)
    get "/dashboard/eportfolios"
    f(".add_eportfolio_link").click
    wait_for_animations
    replace_content f("#eportfolio_name"), "student content"
    f("#eportfolio_public").click if is_public
    expect_new_page_load { f("#eportfolio_submit").click }
    eportfolio = Eportfolio.find_by_name("student content")
    eportfolio.should be_valid
    eportfolio.public.should be_true if is_public
    f('#content h2').should include_text(I18n.t('headers.welcome', "Welcome to Your ePortfolio"))
  end

  def entry_verifier(opts={})
    @eportfolio.eportfolio_entries.count > 0
    entry= @eportfolio.eportfolio_entries.first
    if opts[:section_type]
      entry.content.first[:section_type].should eql(opts[:section_type])
    end

    if opts[:content]
      entry.content.first[:content].should include_text(opts[:content])
    end
  end

  before (:each) do
    course_with_student_logged_in
  end

  it "should create an eportfolio" do
    create_eportfolio
  end

  it "should create an eportfolio that is public" do
    create_eportfolio(true)
  end

  context "eportfolio created with user" do
    before(:each) do
      eportfolio_model({:user => @user, :name => "student content"})
    end

    it "Should start the download of ePortfolio contents" do
      get "/eportfolios/#{@eportfolio.id}"
      f(".download_eportfolio_link").click
      f("#export_progress").should be_displayed
    end

    it "should display and hide eportfolio wizard" do
      get "/eportfolios/#{@eportfolio.id}"
      f(".wizard_popup_link").click
      wait_for_animations
      f("#wizard_box").should be_displayed
      f(".close_wizard_link").click
      wait_for_animations
      f("#wizard_box").should_not be_displayed
    end

    it "should add a section" do
      get "/eportfolios/#{@eportfolio.id}"
      f("#section_list_manage .manage_sections_link").click
      f("#section_list_manage .add_section_link").click
      f("#section_list input").send_keys("test section name", :return)
      wait_for_ajax_requests
      find_with_jquery("#section_list li:last-child .name").text.should eql "test section name"
    end

    it "should edit ePortfolio settings" do
      get "/eportfolios/#{@eportfolio.id}"
      f('#section_list_manage .portfolio_settings_link').click
      replace_content f('#edit_eportfolio_form #eportfolio_name'), "new ePortfolio name"
      f('#edit_eportfolio_form #eportfolio_public').click
      f('#edit_eportfolio_form button[type=submit]').click
      wait_for_ajax_requests
      @eportfolio.reload
      @eportfolio.name.should eql "new ePortfolio name"
    end

    it "should have a working flickr search dialog" do
      skip_if_ie("Out of memory / stack overflow")
      get "/eportfolios/#{@eportfolio.id}"
      edit_link = keep_trying_until do
        f("#page_list a.page_url").click
        f("#page_sidebar .edit_content_link")
      end
      edit_link.click
      f('.add_content_link.add_rich_content_link').click
      wait_for_tiny(f('textarea.edit_section'))
      f("img[alt='Embed Image']").click
      f(".flickr_search_link").click
      f("#instructure_image_search").should be_displayed
    end


    it "should not have new section option when adding submission" do
      @assignment = @course.assignments.create!(:title => "hardest assignment ever", :submission_types => "online_url,online_upload")
      @submission = @assignment.submit_homework(@student)
      @submission.submission_type = "online_url"
      @submission.save!
      get "/eportfolios/#{@eportfolio.id}"
      f(".submission").click
      f("#add_submission_form").should be_displayed
      ff(:css, '#category_select option').map(&:text).should_not include("New Section")
    end


    it "should delete the ePortfolio" do
      get "/eportfolios/#{@eportfolio.id}"
      wait_for_ajax_requests
      f(".delete_eportfolio_link").click
      delete_button = f("#delete_eportfolio_form button[type=submit]")
      delete_button.should be_displayed
      delete_button.click
      f("#wrapper-container .eportfolios").click
      f("#whats_an_eportfolio .add_eportfolio_link").should be_displayed
      fj("#portfolio_#{@eportfolio.id}").should be_nil
      Eportfolio.first.workflow_state.should eql 'deleted'
    end

    describe "add content box" do
      before(:each) do
        @assignment = @course.assignments.create(:name => 'new assignment')
        @assignment.submit_homework(@student)
        get "/eportfolios/#{@eportfolio.id}"
        expect_new_page_load { f(".forward").click }
        f(".edit_content_link").click
      end

      it "should click on the How Do I..? button" do
        f(".wizard_popup_link").click
        f("#wizard_box .wizard_options_list").should be_displayed
      end

      it "should add rich text content" do
        f(".add_rich_content_link").click
        type_in_tiny "textarea", "hello student"
        f(".form_content button[type='submit']").click
        wait_for_ajax_requests
        entry_verifier ({:section_type => "rich_text", :content => "hello student"})
        f("#page_content .section_content").should include_text("hello student")
      end

      context "adding html content" do
        before(:each) do
          @html_content="<b>student</b>"
          f(".add_html_link").click
          f("#edit_page_section_1").send_keys(@html_content)
        end

        def add_html
          f(".form_content button[type='submit']").click
          wait_for_ajax_requests
          f(".section_content b").text.should eql "student"
          entry_verifier ({:section_type => "html", :content => @html_content})
        end

        def put_comment_in_html
          allow_comments = "#eportfolio_entry_allow_comments"
          f(allow_comments).click
          is_checked(allow_comments).should be_true
          comment_public="#eportfolio_entry_show_comments"
          f(comment_public).click
          is_checked(comment_public).should be_true
          f(".form_content button[type='submit']").click
          f(".section_content b").text.should eql "student"
          entry_verifier ({:section_type => "html", :content => @html_content})
          refresh_page
          f("#page_comment_message").send_keys("hi student")
          f("#add_page_comment_form button[type='submit']").click
          wait_for_ajax_requests
          f("#page_comments .message").should include_text("hi student")
          @eportfolio_entry.page_comments[0].message.should eql "hi student"
        end

        it "should verify that the html is there" do
          add_html
        end

        it "should put comment in html" do
          put_comment_in_html
        end


        it "should delete the html content" do
          add_html
          f(".edit_content_link").click
          hover_and_click("#page_section_1 .delete_page_section_link")
          driver.switch_to.alert.accept
          wait_for_ajaximations
          f(".form_content button[type='submit']").click
          wait_for_ajaximations
          @eportfolio.eportfolio_entries.first.content[0].should eql "No Content Added Yet"
          f("#edit_page_section_1").should be_nil
        end

        it "should delete html comment" do
          put_comment_in_html
          PageComment.count>0
          f(".delete_comment_link").click
          driver.switch_to.alert.accept
          wait_for_ajaximations
          f("#page_comments .message").should be_nil
          PageComment.count.should eql 0
        end
      end

      it "should add a course submission" do
        f(".add_submission_link").click
        f(".submission_list").should include_text(@assignment.title)
        f(".select_submission_button").click
        f(".form_content button[type='submit']").click
      end
    end

    it "should click on all wizard options and validate the text" do
      get "/eportfolios/#{@eportfolio.id}"
      f('.wizard_popup_link').click
      wait_for_ajaximations
      options_text = {'.information_step' => "ePortfolios are a place to demonstrate your work.",
                      '.portfolio_step' => "Sections are listed along the left side of the window",
                      '.section_step' => "Sections have multiple pages",
                      '.adding_submissions' => "You may have noticed at the bottom of this page is a list of recent submissions",
                      '.edit_step' => "To change the settings for your ePortfolio",
                      '.publish_step' => "Ready to get started?"}
      options_text.each do |option, text|
        f(option).click
        wait_for_animations
        f('.wizard_details .details').text.should include_text text
      end
    end
  end
end

describe "eportfolios file upload" do
  it_should_behave_like "forked server selenium tests"

  before (:each) do
    @password = "asdfasdf"
    @student = user_with_pseudonym :active_user => true,
                                   :username => "student@example.com",
                                   :password => @password
    @student.save!
    @course = course :active_course => true
    @course.enroll_student(@student).accept!
    @course.reload
    eportfolio_model({:user => @user, :name => "student content"})
  end

  it "should upload a file" do
    login_as(@student.email, @password)
    get "/eportfolios/#{@eportfolio.id}"
    filename, fullpath, data = get_file("testfile5.zip")
    expect_new_page_load { f(".forward").click }
    f(".edit_content_link").click
    f(".add_file_link").click
    fj(".file_upload:visible").send_keys(fullpath)
    fj(".upload_file_button").click
    wait_for_ajaximations
    f(".form_content button[type='submit']").click
    wait_for_ajax_requests
    download = f("a.eportfolio_download")
    download.should be_displayed
    download.attribute('href').should_not be_nil
    #cannot test downloading the file, will check in the future
    #check_file(download)
  end
end