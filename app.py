from flask import Flask, request, render_template, jsonify, redirect
import requests

app = Flask(__name__)

# Route for the input form
@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        state_case = request.form['stateCase']
        case_year = request.form['caseYear']
        state = request.form['state']
        return redirect(f'/results?stateCase={state_case}&caseYear={case_year}&state={state}')
    return render_template('index.html')

# Route for displaying results
@app.route('/results')
def results():
    state_case = request.args.get('stateCase')
    case_year = request.args.get('caseYear')
    state = request.args.get('state')
    
    # Call the NHTSA Crash API
    url = f"https://crashviewer.nhtsa.dot.gov/CrashAPI/crashes/GetCaseDetails?stateCase={state_case}&caseYear={case_year}&state={state}&format=json"
    response = requests.get(url)
    
    if response.status_code != 200:
        return render_template('results.html', data={"error": "Failed to retrieve data from the API."})

    data = response.json()  # Assuming the API returns JSON data

    return render_template('results.html', data=data)

# API endpoint for cURL
@app.route('/api/crashdata', methods=['GET'])
def api_crashdata():
    state_case = request.args.get('stateCase')
    case_year = request.args.get('caseYear')
    state = request.args.get('state')
    
    # Call the NHTSA Crash API
    url = f"https://crashviewer.nhtsa.dot.gov/CrashAPI/crashes/GetCaseDetails?stateCase={state_case}&caseYear={case_year}&state={state}&format=json"
    response = requests.get(url)
    
    if response.status_code != 200:
        return jsonify({"error": "Failed to retrieve data from the API."}), response.status_code

    data = response.json()

    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True)