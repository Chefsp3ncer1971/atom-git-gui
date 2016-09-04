path = require 'path'
Git = require 'nodegit'
{$, View} = require 'space-pen'

module.exports =
  class GitGuiRepoView extends View
    @content: ->
      @div class: 'git-gui-settings-subview', id: 'repo-view', =>
        @h1 id: 'branch', 'Branch'
        @div =>
          @select class: 'input-select', id: 'git-gui-branch-list'

    initialize: ->
      @setBranches()
      $(document).ready () =>
        $('#git-gui-branch-list').on 'change', () =>
          @changeBranch()

    destroy: ->

    setBranches: ->
      pathToRepo = path.join atom.project.getPaths()[0], '.git'
      Git.Repository.open pathToRepo
      .then (repo) ->
        repo.getReferences(Git.Reference.TYPE.LISTALL)
        .then (refs) ->
          for ref in refs
            if ref.isRemote()
              continue

            option = "<option value=#{ref.name()}>#{ref.shorthand()}</option>"
            $('#git-gui-branch-list').append $(option)

            if ref.isHead()
              $('#git-gui-branch-list').val(ref.name())
              @currentBranch = ref.name()
      .catch (error) ->
        console.log error

    changeBranch: ->
      pathToRepo = path.join atom.project.getPaths()[0], '.git'
      Git.Repository.open pathToRepo
      .then (repo) ->
        repo.getReference $('#git-gui-branch-list').val()
        .then (ref) ->
          checkoutOptions = new Git.CheckoutOptions()
          repo.checkoutBranch ref, checkoutOptions
          .then () ->
            @currentBranch = ref.name()
      .catch (error) ->
        console.log error
        atom.notifications.addError "Branch checkout unsuccessful: #{error}"
        $('#git-gui-branch-list').val(@currentBranch)