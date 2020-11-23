require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
# require 'sinatra/content_for'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  erb markdown.render(text), layout: :layout
end

def load_file_contents(file_path)
  case File.extname(file_path)
  when '.md'
    headers['Content-Type'] = 'text/html;charset=utf-8'
    render_markdown(File.read(file_path))
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    File.read(file_path)
  end
end

helpers do
  def display_alert
    session.delete(:message)
  end

  def display_contents(file_path)
    File.read(file_path)
  end
end

# Display index of files
get '/' do
  @files = Dir.glob(File.join(data_path, '*')).map { |file| File.basename(file) }
  erb :index, layout: :layout
end

# Display contents of specific file
get '/:filename' do
  file_path = File.join(data_path, params[:filename])
  if File.exist?(file_path)
    load_file_contents(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

# Display form to edit an individual file
get '/:filename/edit' do
  @file_path = File.join(data_path, params[:filename])
  @file_name = File.basename(@file_path)
  if File.exist?(@file_path)
    erb :edit_file, layout: :layout
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

# Edit an individual file
post '/:filename/edit' do
  @file_path = File.join(data_path, params[:filename])
  edited_contents = params[:edit_contents]
  File.write(@file_path, edited_contents)
  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end
