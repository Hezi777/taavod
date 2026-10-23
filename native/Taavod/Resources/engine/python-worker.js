// Pinned module worker. Python and packages load only when a Python exercise runs.
import { loadPyodide } from '/packs/python/pyodide.mjs';
let pyodidePromise;

function loadRuntime() {
 if (!pyodidePromise) {
  pyodidePromise = (async () => {
   self.postMessage({status:'Loading Python and pandas… First use downloads the runtime.'});
   const py = await loadPyodide({indexURL:'/packs/python/'});
   self.postMessage({status:'Python runtime is ready. Loading pandas and matplotlib…'});
   await py.loadPackage(['pandas','matplotlib']);
   return py;
  })().catch(error => { pyodidePromise = undefined; throw error; });
 }
 return pyodidePromise;
}

self.onmessage = async ({data}) => {
 try {
  const py = await loadRuntime();
  self.postMessage({status:'Python and pandas are ready. Running your code…'});
  py.globals.set('submitted_code',data.answer);
  py.globals.set('reference_code',data.solution);
  const outcome = await py.runPythonAsync(`
import pandas as pd, json, math, io, base64
from contextlib import redirect_stdout
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def canonical(value):
    if hasattr(value, 'item'):
        value = value.item()
    if isinstance(value, dict):
        return {str(k): canonical(v) for k,v in value.items()}
    if isinstance(value, (list, tuple)):
        return [canonical(v) for v in value]
    if isinstance(value, float):
        return round(value, 7) if math.isfinite(value) else str(value)
    return value

fixtures = [
    [[1,'C1','North','2026-01-01',100,20],[2,'C1','North','2026-01-02',100,30],[3,'C2','South','2026-01-02',0,0],[4,'C3','South','2026-02-01',-20,-5],[5,'C2','South','2026-02-01',200,40],[6,'C1','East','2026-01-02',50,5]],
    [[11,'A','West','2026-03-01',10,2],[12,'A','West','2026-03-01',-10,-1],[13,'B','East','2026-03-02',0,0]],
]
passed = True
output = ''
first_result = None
plot = None
for i, rows in enumerate(fixtures):
    frame = pd.DataFrame(rows, columns=['order_id','customer_id','region','order_date','revenue','profit'])
    frame['order_date'] = pd.to_datetime(frame['order_date'])
    expected_env = {'pd':pd,'df':frame.copy(deep=True)}
    exec(reference_code, expected_env)
    expected = canonical(expected_env['result'])
    user_env = {'pd':pd,'df':frame.copy(deep=True),'plt':plt}
    capture = io.StringIO()
    with redirect_stdout(capture):
        exec(submitted_code, user_env)
    if 'result' not in user_env:
        raise ValueError('Assign your answer to a variable named result.')
    actual = canonical(user_env['result'])
    passed = passed and actual == expected
    if i == 0:
        first_result = actual
        output = capture.getvalue()
        if plt.get_fignums():
            buffer = io.BytesIO()
            plt.gcf().savefig(buffer, format='png', bbox_inches='tight')
            plot = 'data:image/png;base64,' + base64.b64encode(buffer.getvalue()).decode()
    plt.close('all')
json.dumps({'passed': bool(passed), 'checks': 2, 'output': output + '\\nresult = ' + json.dumps(first_result), 'plot': plot})
`);
  const result = JSON.parse(outcome);
  result.feedback=result.passed?'Your result matches on both synthetic datasets, including a zero-total-revenue case. Explain why it works before moving on.':'Your result differs on at least one dataset. Check result type, duplicate customers, same-date ties, and zero denominators.';
  self.postMessage({result});
 }catch(error){self.postMessage({error:error instanceof Error?error.message:String(error)});}
};
