(function (ace_editor) {
  /**
   * Look at http://jsonpatch.com/ to see existing operations.
   * @param editor
   * @param content_type
   * @param patches
   */
  function patch(editor, content_type, patches) {
    var rawEditorContent = editor.getValue();
    if (content_type == "YAML") {
      formatParser = jsyaml.load;
      formatStringifier = jsyaml.dump;
    } else if (content_type == "JSON") {
      formatParser = JSON.parse;
      formatStringifier = JSON.stringify;
    } else {
      throw `Undefined content type: ${content_type}. Use "JSON" or "YAML".`
    };
    if (patches.constructor === Object) {
      patches = [patches];
    } else if (patches.constructor === Array) {
      patches = patches.map((patch) => JSON.parse(patch));
    };
    editorContent = formatParser(rawEditorContent);
    window.qe_jsonpatch.apply(editorContent, patches);
    rawEditorContent = formatStringifier(editorContent, null, 2);
    return editor.setValue(rawEditorContent);
  }
  ace_editor.patch = patch;

})(window.qe_ace_editor || (window.qe_ace_editor = {}));
