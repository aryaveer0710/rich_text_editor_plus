import '../theme.dart';

/// Generates the full HTML document for the contenteditable editor.
///
/// Communication protocol:
///   Flutter → JS:  evaluateJavascript calling window.editorBridge.*
///   JS → Flutter:  window.flutter_channel.postMessage(JSON.stringify({...}))
///                   On web: window.parent.postMessage(...)
///
/// Message types FROM JS to Flutter:
///   { type: 'contentChanged', html: '...', plainText: '...' }
///   { type: 'selectionStyle', bold: bool, italic: bool, ... }
///   { type: 'ready' }
///   { type: 'focus' }
///   { type: 'blur' }
///   { type: 'linkRequest' }  (when user presses Ctrl+K)
String generateEditorHtml(RichEditorTheme theme) {
  final bgColor = _colorToCss(theme.editorBackground);
  final textColor = _colorToCss(theme.editorTextColor);
  final placeholderColor = _colorToCss(theme.placeholderColor);
  final fontFamily = theme.editorFontFamily;
  final fontSize = theme.editorFontSize;
  final lineHeight = theme.editorLineHeight;
  final paddingTop = theme.editorPadding.top;
  final paddingRight = theme.editorPadding.right;
  final paddingBottom = theme.editorPadding.bottom;
  final paddingLeft = theme.editorPadding.left;
  final placeholder = _escapeHtml(theme.placeholder ?? '');

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  html, body {
    height: 100%;
    width: 100%;
    overflow: hidden;
    background: $bgColor;
  }

  #editor {
    width: 100%;
    min-height: 100%;
    padding: ${paddingTop}px ${paddingRight}px ${paddingBottom}px ${paddingLeft}px;
    font-family: $fontFamily;
    font-size: ${fontSize}px;
    line-height: $lineHeight;
    color: $textColor;
    background: $bgColor;
    outline: none;
    overflow-y: auto;
    word-wrap: break-word;
    white-space: pre-wrap;
  }

  #editor:empty:before {
    content: attr(data-placeholder);
    color: $placeholderColor;
    pointer-events: none;
    display: block;
  }

  /* List styles */
  #editor ol, #editor ul {
    padding-left: 24px;
    margin: 4px 0;
  }

  #editor ol ol, #editor ul ul, #editor ol ul, #editor ul ol {
    margin: 2px 0;
  }

  #editor li {
    margin: 2px 0;
  }

  /* Link styles */
  #editor a {
    color: #1A73E8;
    text-decoration: underline;
    cursor: pointer;
  }

  /* Paragraph spacing */
  #editor p {
    margin: 0;
    min-height: 1em;
  }

  #editor p + p {
    margin-top: 0.4em;
  }

  /* Prevent pasted images from breaking layout */
  #editor img {
    max-width: 100%;
    height: auto;
  }
</style>
</head>
<body>
<div id="editor" contenteditable="true" data-placeholder="$placeholder" spellcheck="true"></div>

<script>
(function() {
  'use strict';

  var editor = document.getElementById('editor');
  var isComposing = false;
  var debounceTimer = null;

  // -----------------------------------------------------------------------
  // Communication: send messages to Flutter
  // -----------------------------------------------------------------------
  function sendToFlutter(data) {
    var msg = JSON.stringify(data);
    try {
      // Mobile WebView channel (Android/iOS)
      if (window.flutter_channel && window.flutter_channel.postMessage) {
        window.flutter_channel.postMessage(msg);
        return;
      }
      // Web platform: postMessage to parent frame
      if (window.parent && window.parent !== window) {
        window.parent.postMessage(msg, '*');
        return;
      }
      // Fallback: custom event
      window.dispatchEvent(new CustomEvent('editorMessage', { detail: msg }));
    } catch (e) {
      console.error('sendToFlutter error:', e);
    }
  }

  // -----------------------------------------------------------------------
  // Content reporting
  // -----------------------------------------------------------------------
  function reportContent() {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function() {
      sendToFlutter({
        type: 'contentChanged',
        html: editor.innerHTML,
        plainText: getPlainText()
      });
    }, 50);
  }

  function getPlainText() {
    return domToPlainText(editor).replace(/\\n{3,}/g, '\\n\\n').trim();
  }

  function domToPlainText(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      return node.textContent;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return '';

    var tag = node.tagName.toLowerCase();
    var result = '';

    // Handle list items with bullet/number prefix
    if (tag === 'li') {
      var parent = node.parentElement;
      var prefix = '';
      if (parent && parent.tagName.toLowerCase() === 'ol') {
        var index = Array.from(parent.children).indexOf(node) + 1;
        prefix = index + '. ';
      } else {
        prefix = '\\u2022 ';
      }
      // Calculate nesting depth for indentation
      var depth = 0;
      var p = node.parentElement;
      while (p && p !== editor) {
        if (p.tagName.toLowerCase() === 'ol' || p.tagName.toLowerCase() === 'ul') {
          depth++;
        }
        p = p.parentElement;
      }
      var indent = '  '.repeat(Math.max(0, depth - 1));
      var childText = '';
      for (var i = 0; i < node.childNodes.length; i++) {
        childText += domToPlainText(node.childNodes[i]);
      }
      var lines = childText.split('\\n');
      result = indent + prefix + lines[0];
      for (var j = 1; j < lines.length; j++) {
        result += '\\n' + lines[j];
      }
      result += '\\n';
      return result;
    }

    // Block-level elements get line breaks
    var isBlock = ['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
                   'blockquote', 'pre', 'ol', 'ul', 'table', 'hr'].indexOf(tag) >= 0;

    for (var k = 0; k < node.childNodes.length; k++) {
      result += domToPlainText(node.childNodes[k]);
    }

    if (tag === 'br') return '\\n';
    if (isBlock && result.length > 0) {
      if (tag !== 'ol' && tag !== 'ul') {
        if (!result.endsWith('\\n')) result += '\\n';
      }
    }

    return result;
  }

  // -----------------------------------------------------------------------
  // Selection style reporting
  // -----------------------------------------------------------------------
  function reportSelectionStyle() {
    var linkUrl = null;
    var sel = window.getSelection();
    if (sel && sel.rangeCount > 0) {
      var node = sel.anchorNode;
      while (node && node !== editor) {
        if (node.nodeType === Node.ELEMENT_NODE && node.tagName.toLowerCase() === 'a') {
          linkUrl = node.getAttribute('href');
          break;
        }
        node = node.parentNode;
      }
    }

    var alignment = 'left';
    if (sel && sel.rangeCount > 0) {
      var block = sel.anchorNode;
      while (block && block !== editor) {
        if (block.nodeType === Node.ELEMENT_NODE) {
          var ta = block.style.textAlign || window.getComputedStyle(block).textAlign;
          if (ta === 'center' || ta === 'right' || ta === 'justify') {
            alignment = ta;
            break;
          }
          var align = block.getAttribute('align');
          if (align) {
            alignment = align;
            break;
          }
        }
        block = block.parentNode;
      }
    }

    sendToFlutter({
      type: 'selectionStyle',
      bold: document.queryCommandState('bold'),
      italic: document.queryCommandState('italic'),
      underline: document.queryCommandState('underline'),
      strikethrough: document.queryCommandState('strikeThrough'),
      orderedList: document.queryCommandState('insertOrderedList'),
      unorderedList: document.queryCommandState('insertUnorderedList'),
      linkUrl: linkUrl,
      alignment: alignment
    });
  }

  // -----------------------------------------------------------------------
  // Bridge API: called from Flutter via evaluateJavascript
  // -----------------------------------------------------------------------
  window.editorBridge = {

    execCommand: function(command, value) {
      editor.focus();
      document.execCommand(command, false, value || null);
      reportContent();
      reportSelectionStyle();
    },

    insertLink: function(url, text) {
      editor.focus();
      var sel = window.getSelection();
      if (sel.toString().length > 0) {
        document.execCommand('createLink', false, url);
      } else if (text) {
        var a = document.createElement('a');
        a.href = url;
        a.textContent = text;
        a.target = '_blank';
        var range = sel.getRangeAt(0);
        range.insertNode(a);
        range.setStartAfter(a);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
      } else {
        document.execCommand('createLink', false, url);
      }
      reportContent();
      reportSelectionStyle();
    },

    removeLink: function() {
      editor.focus();
      document.execCommand('unlink', false, null);
      reportContent();
      reportSelectionStyle();
    },

    setHtml: function(html) {
      editor.innerHTML = html;
      reportContent();
    },

    getHtml: function() {
      return editor.innerHTML;
    },

    getPlainText: function() {
      return getPlainText();
    },

    insertHtml: function(html) {
      editor.focus();
      document.execCommand('insertHTML', false, html);
      reportContent();
    },

    clear: function() {
      editor.innerHTML = '';
      reportContent();
    },

    focus: function() {
      editor.focus();
    },

    blur: function() {
      editor.blur();
    },

    setAlignment: function(alignment) {
      editor.focus();
      switch (alignment) {
        case 'left':
          document.execCommand('justifyLeft', false, null);
          break;
        case 'center':
          document.execCommand('justifyCenter', false, null);
          break;
        case 'right':
          document.execCommand('justifyRight', false, null);
          break;
        case 'justify':
          document.execCommand('justifyFull', false, null);
          break;
      }
      reportContent();
      reportSelectionStyle();
    },

    isEmpty: function() {
      var text = editor.innerText.trim();
      return text.length === 0 || text === '\\n';
    }
  };

  // -----------------------------------------------------------------------
  // Event listeners
  // -----------------------------------------------------------------------

  editor.addEventListener('input', function() {
    if (!isComposing) {
      reportContent();
    }
  });

  editor.addEventListener('compositionstart', function() {
    isComposing = true;
  });

  editor.addEventListener('compositionend', function() {
    isComposing = false;
    reportContent();
  });

  document.addEventListener('selectionchange', function() {
    reportSelectionStyle();
  });

  editor.addEventListener('focus', function() {
    sendToFlutter({ type: 'focus' });
  });

  editor.addEventListener('blur', function() {
    sendToFlutter({ type: 'blur' });
    reportContent();
  });

  // Paste: let the browser handle it natively, then report changes
  editor.addEventListener('paste', function(e) {
    setTimeout(function() {
      reportContent();
      reportSelectionStyle();
    }, 50);
  });

  // Keyboard shortcuts
  editor.addEventListener('keydown', function(e) {
    if ((e.ctrlKey || e.metaKey) && !e.shiftKey) {
      switch (e.key.toLowerCase()) {
        case 'b':
          e.preventDefault();
          window.editorBridge.execCommand('bold');
          break;
        case 'i':
          e.preventDefault();
          window.editorBridge.execCommand('italic');
          break;
        case 'u':
          e.preventDefault();
          window.editorBridge.execCommand('underline');
          break;
        case 'k':
          e.preventDefault();
          sendToFlutter({ type: 'linkRequest' });
          break;
      }
    }
  });

  // Signal ready
  sendToFlutter({ type: 'ready' });

})();
</script>
</body>
</html>
''';
}

/// Convert a Flutter Color to a CSS color string.
String _colorToCss(dynamic color) {
  try {
    final int value = (color as dynamic).value;
    final int r = (value >> 16) & 0xFF;
    final int g = (value >> 8) & 0xFF;
    final int b = value & 0xFF;
    final double a = ((value >> 24) & 0xFF) / 255.0;
    if (a < 1.0) {
      return 'rgba($r, $g, $b, ${a.toStringAsFixed(2)})';
    }
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  } catch (_) {
    return '#000000';
  }
}

/// Escape HTML special characters in a string.
String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
