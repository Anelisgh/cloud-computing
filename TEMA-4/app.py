from flask import Flask, request, jsonify, render_template
import os
from openai import AzureOpenAI

app = Flask(__name__)

azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
azure_api_key = os.getenv("AZURE_OPENAI_API_KEY")
deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME")

client = AzureOpenAI(
    api_version="2024-02-15-preview",
    azure_endpoint=azure_endpoint,
    api_key=azure_api_key
)

@app.route('/', methods=['GET'])
def home():
    return render_template('index.html')

@app.route('/info', methods=['GET'])
def info():
    return jsonify({
        "name": "Code Explanation Plugin",
        "description": "Explains code snippets by analyzing their functionality and purpose",
        "version": "1.0.0"
    })

@app.route('/prompt', methods=['POST'])
def prompt():
    try:
        data = request.get_json()
        
        if not data or 'prompt' not in data:
            return jsonify({
                "error": "Missing required field: prompt"
            }), 400
        
        user_prompt = data['prompt']
        
        if not user_prompt or not user_prompt.strip():
            return jsonify({
                "error": "Prompt cannot be empty"
            }), 400
        
        system_message = "You are a helpful coding assistant that explains code clearly and concisely."
        
        try:
            response = client.chat.completions.create(
                model=deployment_name,
                messages=[
                    {"role": "system", "content": system_message},
                    {"role": "user", "content": f"Explain this code:\n\n{user_prompt}"}
                ],
                max_tokens=1000,
                temperature=0.7
            )
            
            explanation = response.choices[0].message.content
            
            return jsonify({
                "explanation": explanation,
                "status": "success"
            }), 200
            
        except Exception as openai_error:
            return jsonify({
                "error": "Azure OpenAI request failed",
                "details": str(openai_error)
            }), 502
    
    except Exception as e:
        return jsonify({
            "error": "Internal server error",
            "details": str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8000))
    app.run(host='0.0.0.0', port=port)