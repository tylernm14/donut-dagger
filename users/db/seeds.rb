require_relative '../app/models/user'
require_relative '../app/models/token'

u = User.create(login: 'robot', name: 'robot', email: 'robot@robots.com')
t = Token.create(user: u, value: 'devtoken')
