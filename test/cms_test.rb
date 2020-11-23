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

  def test_index
    create_file('about.txt')
    create_file('changes.txt')

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.txt'
    assert_includes last_response.body, 'changes.txt'
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

    get '/about.md/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Edit contents of about.md'
    assert_includes last_response.body, 'textarea'
    assert_includes last_response.body, 'submit'
    assert_includes last_response.body, 'Save Changes'
  end

  def test_edit_file
    create_file('test.txt', 'This is a test file.')

    post '/test.txt/edit', params={edit_contents: "This is a test file. It's been tested."}
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
end
