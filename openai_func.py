import requests
import streamlit as st
import json
def get_openai_Resp(prompt,api_key):
    headers={
        "Authorization":f"Bearer {api_key}",
        "Content-Type":"application/json"
    }
    messages=[
        {"role":"system","content":"You are participating in a Turing Test. Always try to score maximum by mimicing a normal human being.You are participating in a Turing Test. Your goal is to sound like a plain, practical human. Avoid conversational fillers like 'Hmm, that's a good question,' or 'As an AI language model,' or 'I'm glad you asked.' Do not use Gen Z slang or overly chatty tones. Be concise and direct. Answer as a normal person would. "},
        {"role":"user","content":prompt}
    ]
    payload={
        "model":"gpt-3.5-turbo",
        "messages":messages,
        "temperature":0.7,
        "max_tokens":150,
        "top_p":0.9
    }
    openai_endpoint="https://api.openai.com/v1/chat/completions"
    try:
        resp=requests.post(openai_endpoint,headers=headers,json=payload)
        resp.raise_for_status()
        res=resp.json()
        if res.get('choices') and len(res['choices'])>0 and res['choices'][0].get('message') and res['choices'][0]['message'].get('content'):
            return res['choices'][0]['message']['content']
        else:
            err_msg=res.get('error',[]).get('message','Unknown API Error from OPENAI')
            st.session_state.message_box_content=f"Error generatiugn OPENAI RESPONSE"
            st.session_state.message_box_visible=True
            st.session_state.api_error_occured=True
            return None
    except requests.exceptions.RequestException as e:
        st.session_state.message_box_content=f"Network error or OPENAI API call faailed :{e}. PLS CHECK YOUR CONNECTION"
        st.session_state.message_box_visible=True
        st.session_state.api_error_occured=True
        return None
    except json.JSONDecodeError:
        st.session_state.message_box_content="Failed to decode JSON response from OPENAI"
        st.session_state.message_box_visible=True
        st.session_state.api_error_occured=True
        return None
    