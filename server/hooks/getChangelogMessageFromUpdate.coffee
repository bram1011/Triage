@getEventMessagesFromUpdate = (userId, doc, fn, modifier) ->
  user = Meteor.users.findOne(userId)
  author = Meteor.users.findOne(doc.authorId)
  title = validator.escape(doc.title)
  body = validator.escape(doc.body)
  switch fn
    when 'tags'
      type = "field"
      if modifier.$addToSet?.tags?
        tags = _.difference modifier.$addToSet.tags.$each, doc.tags
        unless tags.length is 0
          changelog = "added tag(s) #{tags}"
          _.each tags, (x) ->
            Tags.upsert {name: x}, {$set: {lastUse: new Date()}}

      if modifier.$pull?.tags?
        changelog = "removed tag(s) #{modifier.$pull.tags}"

    when 'status'
      oldStatus = validator.escape(doc.status)
      newStatus = validator.escape(modifier.$set.status)
      unless oldStatus is newStatus
        type = "field"
        changelog = "changed status from #{oldStatus} to #{newStatus}"
        subject = "User #{user.username} changed status for Triage ticket ##{doc.ticketNumber}: #{title}"
        emailBody ="<strong>User #{user.username} changed status for ticket ##{doc.ticketNumber} from
          #{oldStatus} to #{newStatus}.</strong><br>
          The original ticket body was:<br>
          #{body}"

        recipients = []
        if author.notificationSettings?.authorStatusChanged
          recipients.push(author.mail)

        _.each doc.associatedUserIds, (a) ->
            aUser = Meteor.users.findOne(a)
            if aUser.notificationSettings?.associatedStatusChanged
              recipients.push(aUser.mail)


    when 'associatedUserIds'
      type = "field"
      if modifier.$addToSet?.associatedUserIds?.$each?
        users = _.map _.difference(modifier.$addToSet.associatedUserIds.$each, doc.associatedUserIds), (x) ->
          Meteor.users.findOne({_id: x}).username
        unless users.length is 0
          changelog = "associated user(s) #{users}"
      else if modifier.$addToSet?.associatedUserIds?
        user = Meteor.users.findOne(modifier.$addToSet.associatedUserIds).username
        changelog = "associated user #{user}"
      else if modifier.$pull?.associatedUserIds?
        user = Meteor.users.findOne({_id: modifier.$pull.associatedUserIds}).username
        changelog = "disassociated user #{user}"

    when 'attachmentIds'
      type = "attachment"
      if modifier.$addToSet?.attachmentIds
        file = FileRegistry.findOne modifier.$addToSet.attachmentIds
        otherId = file._id
        changelog = "attached file #{file.filename}"
        subject = "User #{user.username} added an attachment to Triage ticket ##{doc.ticketNumber}: #{title}"
        emailBody = "Attachment #{file.filename} added to ticket #{doc.ticketNumber}.
          The original ticket body was:<br>#{body}"

        recipients = []
        if author.notificationSettings?.authorAttachment
          recipients.push(author.mail)

        _.each doc.associatedUserIds, (a) ->
          aUser = Meteor.users.findOne(a)
          if aUser.notificationSettings?.associatedAttachment
            recipients.push(aUser.mail)

      else if modifier.$pull?.attachmentIds
        file = FileRegistry.findOne modifier.$pull.attachmentIds
        otherId = file._id
        changelog = "removed attached file #{file.filename}"

  if changelog
    Changelog.direct.insert
      ticketId: doc._id
      timestamp: new Date()
      authorId: author._id
      authorName: author.username
      type: type
      field: fn
      message: changelog
      otherId: otherId

  if emailBody
    Job.push new NotificationJob
      bcc: _.uniq(recipients)
      ticketId: doc._id
      subject: subject
      html: emailBody
