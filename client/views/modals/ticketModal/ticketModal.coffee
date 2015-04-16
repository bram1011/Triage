Template.ticketModal.helpers
  queues: -> Queues.find()
  settings: ->
    {
      position: "top"
      limit: 5
      rules: [
        {
          token: '@'
          collection: Meteor.users
          field: "username"
          template: Template.userPill
        }
        {
          token: '#'
          #collection: Tags
          field: "name"
        }
      ]
    }

Template.ticketModal.events
  'click button[data-action=submit]': (e, tpl) ->
    #Probably need a record of 'true' submitter for on behalf of submissions.
    
    #Parsing for tags.
    body = tpl.find('textarea[name=body]').value
    title = tpl.find('input[name=title]').value
    hashtags = getTags body
    hashtags = _.uniq hashtags?.concat getTags(title) || []

    #User tagging.
    users = getUsers body
    users = _.uniq users?.concat getUsers(title) || []
    
    #If no onBehalfOf, submitter is the user.
    submitter = tpl.find('input[name=onBehalfOf]').value || Meteor.user().username

    queueNames = tpl.$('select[name=queue]').val()
    if queueNames.length is 0
      #Simpleschema validation will pass with an empty array for queueNames...
      queueNames = null

    Meteor.call 'checkUsername', submitter, (err, res) ->
      if res

        unless submitter is Meteor.user().username
          tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-error').addClass('has-success')
          tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-ok"></span>')
          tpl.$('button[data-action=checkUsername]').removeClass('btn-danger').removeClass('btn-primary').addClass('btn-success')

        id = Tickets.insert {
          title: title
          body: body
          tags: hashtags
          associatedUserIds: users
          queueName: queueNames
          authorId: res
          authorName: submitter
          status: "Open"
          submittedTimestamp: new Date()
          submissionData:
            method: "Web"
        }, (err, res) ->
          if err
            tpl.$('.has-error').removeClass('has-error')
            for key in err.invalidKeys
              tpl.$('[name='+key.name+']').closest('div .form-group').addClass('has-error')
          else
            $('#ticketModal').modal('hide')
            
      else
        tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-success').addClass('has-error')
        tpl.$('button[data-action=checkUsername]').removeClass('btn-success').removeClass('btn-primary').addClass('btn-danger')
        tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-remove"></span>')

  #Username checking and DOM manipulation for on behalf of submission field.
  'click button[data-action=checkUsername]': (e, tpl) ->
    unless tpl.$('input[name="onBehalfOf"]').val() is ""
      Meteor.call 'checkUsername', tpl.$('input[name=onBehalfOf]').val(), (err, res) ->
        if res
          tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-error').addClass('has-success')
          tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-ok"></span>')
          tpl.$('button[data-action=checkUsername]').removeClass('btn-danger').removeClass('btn-primary').addClass('btn-success')
        else
          tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-success').addClass('has-error')
          tpl.$('button[data-action=checkUsername]').removeClass('btn-success').removeClass('btn-primary').addClass('btn-danger')
          tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-remove"></span>')
  
  #When the modal is shown, we get the set of unique tags and update the modal with them.
  #We can't use a true reactive data source for select2 I don't think, so this is the best we've got.
  #This tag-getting is still not ideal. Move into a function or discuss a way of storing unique tags. 
  'shown.bs.modal #ticketModal': (e, tpl) ->
    tags = Tickets.find().fetch().map (x) ->
      return x.tags
    flattened = []
    uniqTags = _.uniq flattened.concat.apply(flattened, tags).filter (n) ->
      return n != undefined
    tpl.$('input[name=tags]').select2({
      tags: uniqTags
      tokenSeparators: [' ', ',']
    })

  'click button[data-dismiss="modal"]': (e, tpl) ->
    tpl.$('input, textarea').val('')
    tpl.$('.has-error').removeClass('has-error')
    tpl.$('button[data-action=checkUsername]').removeClass('btn-success').removeClass('btn-danger').addClass('btn-primary').html('Check')
    tpl.$('select[name=queue]').select2('val', '')
  
 
Template.ticketModal.rendered = () ->
  $('select[name=queue]').select2()
  $('select[name=queue]').select2('val', Session.get('queueName'))

Deps.autorun () ->
  $('select[name=queue]').select2('val', Session.get('queueName'))
