ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_file(file_name, contents='')
    File.open(File.join(data_path, file_name), 'w') do |file|
      file.write(contents)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => { username: "admin" } }
  end

  def sign_in_user
    post '/users/login', params={username: "admin", password: "secret"}
  end

  def test_index
    create_file('about.txt')
    create_file('changes.txt')

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.txt'
    assert_includes last_response.body, 'changes.txt'
    assert_includes last_response.body, 'New Document'
    assert_includes last_response.body, 'delete'
  end

  def test_filename_exists
    create_file('about.txt', 'This is a file based cms program.')

    get '/about.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'This is a file based cms program.'
  end

  def test_filename_not_found
    get '/doesnt_exist.txt'

    assert_equal 302, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'doesnt_exist.txt does not exist'

    get '/'

    assert_equal 200, last_response.status
    refute_includes last_response.body, 'doesnt_exist.txt does not exist'
  end

  def test_viewing_markdown_file
    create_file('about.md', '# Ruby is...')

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end

  def test_edit_file_template
    create_file('about.md')

    get '/about.md/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Edit contents of about.md'
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, 'type="submit"'
    assert_includes last_response.body, 'Save Changes'
  end

  def test_edit_file_template_with_signed_out_user
    create_file('about.md')

    get '/about.md/edit'

    assert_equal 302 || 303, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_edit_file
    create_file('test.txt', 'This is a test file.')

    post '/test.txt/edit', params={edit_contents: "This is a test file. It's been tested."}, admin_session
    assert_equal 302 || 303, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test.txt has been updated.'

    get '/'

    assert_equal 200, last_response.status
    refute_includes last_response.body, 'test.txt has been updated.'

    get '/test.txt'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "This is a test file. It's been tested."
  end

  def test_edit_file_with_signed_out_user
    create_file('about.md')

    post '/test.txt/edit', params={edit_contents: "This is a test file. It's been tested."}

    assert_equal 302 || 303, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_new_file_template
    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Add a new document:'
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, 'Create'
  end

  def test_new_file_template_with_signed_out_user
    create_file('about.md')

    get '/about.md/edit'

    assert_equal 302 || 303, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_file_with_file_extension
    post '/new', params={new_document: 'new_doc_test.txt'}, admin_session

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new_doc_test.txt was created.'

    get '/'

    assert_equal 200, last_response.status
    refute_includes last_response.body, 'new_doc_test.txt was created.'
    assert_includes last_response.body, 'new_doc_test.txt'
  end

  def test_create_new_file_with_no_filename
    post '/new', params={new_document: ''}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_create_new_file_without_file_extension
    post '/new', params={new_document: 'new_doc_test'}, admin_session

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new_doc_test.txt'
  end

  def test_create_new_file_with_signed_out_user
    post '/new', params={new_document: 'new_doc_test'}

    assert_equal 302 || 303, last_response.status
    assert_equal "You must be signed in to do that.", last_request.session[:message]
  end

  def test_delete_file
    create_file('test_file.txt')

    post '/test_file.txt/delete', {}, admin_session

    assert_equal 302, last_response.status
    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'test_file.txt was deleted.'

    get '/'

    assert_equal 200, last_response.status
    refute_includes last_response.body, 'test_file.txt'
  end

  def test_delete_file_with_signed_out_user
    create_file('test_file.txt')

    post '/test_file.txt/delete'

    assert_equal 302 || 303, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_sign_in_button_on_index_when_user_logged_out
    get '/'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Sign In'
  end

  def test_sign_in_page
    get '/users/login'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username'
    assert_includes last_response.body, 'Password'
    assert_includes last_response.body, 'Sign In'
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_failed_login
    post '/users/login', params={username: "testname", password: "password"}

    assert_equal 422, last_response.status

    assert_includes last_response.body, 'Invalid Credentials'
    assert_includes last_response.body, 'testname'
  end

  def test_successful_login
    sign_in_user

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_equal "admin", last_request.session[:username]
    assert_includes last_response.body, 'Welcome!'
    assert_includes last_response.body, 'Signed in as admin.'
    assert_includes last_response.body, 'Sign Out'
  end

  def test_logout
    post '/users/logout', {}, admin_session

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_nil last_request.session[:username]
    assert_includes last_response.body, 'You have been signed out.'
    assert_includes last_response.body, 'Sign In'
  end
end
