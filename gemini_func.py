import requests
import streamlit as st
import json
def get_gem_resp(prompt,api_key):
    chat_hist=[]
    chat_hist.append({"role":"user","parts":[{"text":prompt}]})
    gen_config={
        "temperature":0.7,
        "top_p":0.9,
        "top_k":40,
        "max_output_tokens":150,
        "responseMimeType":"text/plain"
    }
    payload={
        "contents":chat_hist,
        "generationConfig":gen_config
    }
    api_end = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}"
    try:
        resp=requests.post(api_end,headers={'Content-Type':'application/json'},json=payload)
        resp.raise_for_status()
        res=resp.json()
        if res.get('candidates') and len(res['candidates'])>0 and res['candidates'][0].get('content') and res['candidates'][0]['content'].get('parts') and len(res['candidates'][0]['content']['parts'])>0:
            return res['candidates'][0]['content']['parts'][0]['text']
        else:
            err_msg=res.get('error',{}).get('message','Unknown API Error from gemini')
            st.session_state.message_box_content=f"Error generating Gemini Response {err_msg}"
            st.session_state.message_box_visible=True
            st.session_state.api_error_occured=True
            return None
    except requests.exceptions.RequestException as e:
        st.session_state.message_box_content=f"Network errro from gemini"
        st.session_state.message_box_visible=True
        st.session_state.api_error_occured=True
        return None
    except json.JSONDecodeError:
        st.session_state.message_box_content="Failed to decode JSON Response"
        st.session_state.message_box_visible=True
        st.session_state.api_error_occured=True
        return None