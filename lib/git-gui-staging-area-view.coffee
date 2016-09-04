path = require 'path'
{$, View} = require 'space-pen'
Git = require 'nodegit'

module.exports =
  class GitGuiStatusView extends View
    @content: ->
      @div class: 'git-gui-staging-area', =>
        @ol class: 'list-group', id: 'status-list'

    initialize: ->
      pathToRepo = path.join atom.project.getPaths()[0], '.git'
      $(document).ready () =>
        $('#status-list').on 'click', '#staging-area-file', (e) =>
          filename = $(e.target).data("file")
          pathToRepo = path.join atom.project.getPaths()[0], '.git'
          Git.Repository.open pathToRepo
          .then (repo) =>
            repo.refreshIndex()
            .then (index) =>
              # Reset the file if staged
              if $("[id='status-for-#{path.basename filename}']").hasClass 'staged'
                $("[id='status-for-#{path.basename filename}']").removeClass 'staged'
                repo.getHeadCommit()
                .then (commit) ->
                  Git.Reset.default repo, commit, filename
                .then () =>
                  index.write()
                  @updateStatuses()
              # Stage the file
              else
                if $(e.target).prev().prev().hasClass 'status-removed'
                  index.removeByPath filename
                  .then () =>
                    index.write()
                    @updateStatuses()
                else
                  index.addByPath filename
                  .then () =>
                    index.write()
                    @updateStatuses()
          .catch (error) ->
            console.log error

        $('#status-list').on 'click', '#staging-area-file-diff', (e) =>
          $('.git-gui-diff-view').toggleClass 'open'
          $('.git-gui.open').toggleClass 'expanded'
          filename = $(e.target).data("file")
          pathToRepo = path.join atom.project.getPaths()[0], '.git'
          Git.Repository.open pathToRepo
          .then (repo) =>
            repo.getHeadCommit()
            .then (commit) =>
              repo.getTree(commit.treeId())
              .then (tree) =>
                repo.refreshIndex()
                .then (index) =>
                  if $(e.target).data("in-working-tree")
                    Git.Diff.treeToWorkdir(repo, tree, index, null)
                    .then (diff) =>
                      @setDiffText filename, diff
                  else
                    Git.Diff.treeToIndex(repo, tree, index, null)
                    .then (diff) =>
                      @setDiffText filename, diff
          .catch (error) ->
            console.log error

    serialize: ->

    destroy: ->

    updateStatuses: ->
      $('#status-list').empty()
      $('#commit-action').removeClass 'available'

      pathToRepo = path.join atom.project.getPaths()[0], '.git'
      Git.Repository.open pathToRepo
      .then (repo) ->
        repo.getStatus()
        .then (statuses) ->
          for file in statuses
            li = $("<li class='list-item git-gui-status-list-item'></li")
            statusSpan = $("<span class='status icon'></span>")
            stageSpan = $("<span class='icon icon-check' id='status-for-#{path.basename file.path()}'></span>")
            fileSpan = $("<span id='staging-area-file' data-file='#{file.path()}'>#{file.path()}</span>")
            # history = $("<span class='icon icon-history'></span>")
            diffSpan = $("<span class='icon icon-diff' id='staging-area-file-diff' data-file='#{file.path()}' data-in-working-tree='false'></span>")
            li.append statusSpan
            li.append stageSpan
            li.append fileSpan
            # li.append history
            if file.inIndex()
              $('#commit-action').addClass 'available'
              stageSpan.addClass 'staged'
              stageSpan.addClass 'status status-added'
            if file.inWorkingTree()
              stageSpan.addClass 'status status-modified'
              $(diffSpan).data('in-working-tree', 'true')
            if file.isNew()
              statusSpan.addClass 'status-added icon-diff-added'
              value = parseInt($('#added-badge').text(), 10) + 1
              $('#added-badge').text(value)
            if file.isModified()
              li.append diffSpan
              value = parseInt($('#modified-badge').text(), 10) + 1
              $('#modified-badge').text(value)
              statusSpan.addClass 'status-modified icon-diff-modified'
            if file.isDeleted()
              value = parseInt($('#removed-badge').text(), 10) + 1
              $('#removed-badge').text(value)
              statusSpan.addClass 'status-removed icon-diff-removed'
            if file.isRenamed()
              value = parseInt($('#renamed-badge').text(), 10) + 1
              $('#renamed-badge').text(value)
              statusSpan.addClass 'status-renamed icon-diff-renamed'
            if file.isIgnored()
              value = parseInt($('#ignored-badge').text(), 10) + 1
              $('#ignored-badge').text(value)
              statusSpan.addClass 'status-ignored icon-diff-ignored'
            $('#status-list').append li
      .catch (error) ->
        console.log error

    setDiffText: (filename, diff) ->
      $('#diff-text').empty()
      diff.patches()
      .then (patches) ->
        for patch in patches
          if patch.newFile().path() != filename
            continue
          patch.hunks()
          .then (hunks) ->
            for hunk in hunks
              hunk.lines()
              .then (lines) ->
                text = 'diff ' + patch.oldFile().path() + ' ' + patch.newFile().path() + '\n'
                text += hunk.header()
                for line in lines
                  text += String.fromCharCode(line.origin()) + line.content()
                $('#diff-text').append text
            $('.git-gui-overlay').addClass 'fade-and-blur'
