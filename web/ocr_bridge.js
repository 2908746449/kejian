/* Local-only OCR: worker, WASM and Chinese model ship with the app. */
(() => {
  let worker;
  window.kejianRecognizeImage = async bytes => {
    if (!worker) {
      worker = await Tesseract.createWorker('chi_sim', 1, {
        workerPath: new URL('ocr/worker.min.js', document.baseURI).href,
        corePath: new URL('ocr/core', document.baseURI).href,
        langPath: new URL('ocr/lang', document.baseURI).href,
        workerBlobURL: false,
        gzip: true,
      });
      await worker.setParameters({ tessedit_pageseg_mode: '11' });
    }
    const url = URL.createObjectURL(new Blob([bytes], {type:'image/png'}));
    try {
      const {data} = await worker.recognize(url, {}, {blocks:true, text:true});
      const boxes=[];
      for (const block of data.blocks || [])
        for (const para of block.paragraphs || [])
          for (const line of para.lines || [])
            for (const word of line.words || [])
              for (const symbol of word.symbols || []) {
                const b=symbol.bbox;
                boxes.push({text:symbol.text, x:b.x0,y:b.y0,width:b.x1-b.x0,height:b.y1-b.y0});
              }
      return JSON.stringify(boxes);
    } finally { URL.revokeObjectURL(url); }
  };
  window.kejianReleaseRecognizer = async () => {
    const previous=worker;
    worker=undefined;
    if(previous) await previous.terminate();
  };
})();
