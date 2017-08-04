MirrorPool = require 'mirror-pool'
FacebookChat = require 'facebook-chat-api'
pify = require 'pify'

class _FacebookMirror extends MirrorPool.Mirror
	constructor: (@api, @threadId) ->
		super

	inputMatches: (facebookMessage) ->
		facebookMessage.threadID is @threadId

	inputToMessage: (facebookMessage) ->
		attachmentsString \
			= @attachmentsToString facebookMessage.attachments
		senderPromise = @findName \
			facebookMessage.threadID, \
			facebookMessage.senderID
		senderPromise.then (sender) ->
			{
				sender,
				text: facebookMessage.body + attachmentsString
			}

	findName: (threadId, userId) =>
		getNickname = =>
			((pify @api.getThreadInfo) threadId)
			.then (info) ->
				if info.nicknames and info.nicknames[userId]
					return info.nicknames[userId]
				else
					throw new Error 'Could not get nickname'
		getUserName = =>
			(pify @api.getUserInfo) userId
			.then (info) ->
				if info[userId]
					return info[userId].name
				else
					throw new Error 'Could not get name'
		getFallbackName = ->
			Promise.resolve '[Unknown]'

		getNickname()
		.catch ->
			getUserName()
		.catch ->
			getFallbackName()

	attachmentsToString: (attachments) ->
		if attachments and attachments.length > 0
			str = '\n\nAttachments:\n'
			str += attachment.url + '\n' for attachment in attachments
			str
		else
			''

	sendMirrored: (message) ->
		sendPromise = (pify @api.sendMessage) {
			body: @formatMessage message
		}, @threadId
		sendPromise.catch (error) ->
			console.error error

	formatMessage: (message) ->
		message.sender + ': ' + message.text

module.exports = class FacebookBot extends MirrorPool.Bot
	constructor: (@options = {}) ->
		super
		@_clientPromise = (pify FacebookChat) {
			email: @options.email,
			password: @options.password,
		}
		@_clientPromise.then (api) =>
			api.listen (error, message) =>
				if error is null
					@mirrorInput message
				else
					console.error error

	createMirrorCore: (options = {}) ->
		@_clientPromise.then (api) =>
			if not options.threadId
				throw new Error 'Need a thread ID'
			new _FacebookMirror api, options.threadId
