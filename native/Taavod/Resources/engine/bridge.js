let worker;
let current;
let workerKind;
const send = body => window.webkit.messageHandlers.runtime.postMessage(body);
window.runtime = {
  cancel() { worker?.terminate(); worker = undefined; workerKind = undefined; current = undefined; },
  run(request) {
    if (!['sql', 'python'].includes(request.kind)) throw new Error('Unsupported exercise runtime.');
    const kind = request.kind + ':' + request.mode;
    if (!worker || workerKind !== kind) {
      this.cancel();
      worker = new Worker(request.kind === 'sql' ? './sql.worker.js' : './python-worker.js', {type: 'module'});
      workerKind = kind;
    }
    current = request.id;
    worker.onmessage = ({data}) => {
      if (data.status) send({id: current, status: data.status});
      if (data.result) send({id: current, result: data.result});
      if (data.exploreResult) send({id: current, result: {feedback: 'Read-only Pagila exploration. Showing up to 100 rows.', checks: 0, results: [data.exploreResult]}});
      if (data.error) send({id: current, result: {feedback: data.error, error: data.error}});
    };
    worker.onerror = event => send({id: current, result: {feedback: event.message || 'The practice runtime stopped. Retry or reinstall its pack.', error: event.message || 'Runtime error'}});
    worker.postMessage(request);
  }
};
send({ready: true});
