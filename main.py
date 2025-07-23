import streamlit as st
import random
import json
import requests
from gemini_func import get_gem_resp
from openai_func import get_openai_Resp
from human import QUESTIONS
st.set_page_config(page_title="Turing Test Challenge",layout="centered")
st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=Montserrat:wght@400;600;700&display=swap');

    html, body, [class*="st-"] {
        font-family: 'Montserrat', sans-serif;
        color: #333;
    }
    .stApp {
        background: linear-gradient(to bottom right, #e0f7fa, #ffffff);
        padding: 30px;
        border-radius: 20px;
        box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
        max-width: 900px;
        margin: 40px auto;
        animation: fadeIn 1s ease-out;
    }
    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(20px); }
        to { opacity: 1; transform: translateY(0); }
    }
    h1 {
        color: #2c3e50;
        text-align: center;
        margin-bottom: 35px;
        font-weight: 700;
        font-size: 3em;
        letter-spacing: -1px;
        text-shadow: 1px 1px 2px rgba(0,0,0,0.1);
    }
    h2 {
        color: #34495e;
        font-size: 1.8em;
        margin-top: 25px;
        margin-bottom: 20px;
        border-bottom: 2px solid #a7d9f2;
        padding-bottom: 10px;
    }
    .stButton>button {
        background-color: #007bff; /* Blue for primary actions */
        color: white;
        padding: 14px 30px;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        font-size: 1.2em;
        font-weight: 600;
        box-shadow: 0 6px 15px rgba(0, 123, 255, 0.3);
        transition: background-color 0.3s ease, transform 0.2s ease, box-shadow 0.3s ease;
        width: 100%;
        margin-top: 20px;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 10px;
    }
    .stButton>button.stop-button {
        background-color: #dc3545; /* Red for stop button */
        box-shadow: 0 6px 15px rgba(220, 53, 69, 0.3);
    }
    .stButton>button.stop-button:hover {
        background-color: #c82333;
        box-shadow: 0 8px 20px rgba(220, 53, 69, 0.4);
    }
    .stButton>button:hover {
        background-color: #0056b3;
        transform: translateY(-3px);
        box-shadow: 0 8px 20px rgba(0, 123, 255, 0.4);
    }
    .stButton>button:active {
        transform: translateY(0);
        box-shadow: 0 4px 10px rgba(0, 123, 255, 0.2);
    }
    .stRadio > label {
        font-size: 1.1em;
        padding: 10px 0;
    }
    .stRadio div[role="radiogroup"] {
        display: flex;
        flex-direction: column;
        gap: 18px;
    }
    .stRadio div[role="radiogroup"] label {
        background-color: #ffffff;
        border: 1px solid #e0e0e0;
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0 4px 10px rgba(0, 0, 0, 0.08);
        transition: all 0.2s ease;
        line-height: 1.6;
    }
    .stRadio div[role="radiogroup"] label:hover {
        border-color: #007bff;
        box-shadow: 0 6px 15px rgba(0, 123, 255, 0.15);
    }
    .stRadio div[role="radiogroup"] label.selected {
        border-color: #007bff;
        box-shadow: 0 6px 15px rgba(0, 123, 255, 0.2);
        background-color: #e6f2ff;
    }
    .score-box {
        background-color: #d1ecf1;
        padding: 18px;
        border-radius: 12px;
        text-align: center;
        margin-bottom: 35px;
        font-size: 1.4em;
        font-weight: 700;
        color: #0c5460;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        border: 1px solid #bee5eb;
    }
    .question-box {
        background-color: #ffffff;
        padding: 30px;
        border-radius: 15px;
        margin-bottom: 30px;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        font-size: 1.3em;
        font-weight: 600;
        color: #34495e;
        text-align: center;
        border: 1px solid #f0f0f0;
    }
    .message-box {
        background-color: #fff3cd;
        color: #856404;
        padding: 18px;
        border-radius: 10px;
        margin-top: 25px;
        text-align: center;
        font-weight: 500;
        box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
        border: 1px solid #ffeeba;
    }
    .correct-feedback {
        color: #28a745;
        font-weight: bold;
        text-align: center;
        margin-top: 20px;
        font-size: 1.2em;
    }
    .incorrect-feedback {
        color: #dc3545;
        font-weight: bold;
        text-align: center;
        margin-top: 20px;
        font-size: 1.2em;
    }
    .stTextInput>div>div>input {
        border-radius: 8px;
        border: 1px solid #ccc;
        padding: 10px;
        font-size: 1em;
        box-shadow: inset 0 1px 3px rgba(0,0,0,0.06);
    }
    .model-selection-buttons .stButton>button {
        background-color: #6c757d; /* Grey for model selection */
        box-shadow: 0 6px 15px rgba(108, 117, 125, 0.3);
    }
    .model-selection-buttons .stButton>button:hover {
        background-color: #5a6268;
        box-shadow: 0 8px 20px rgba(108, 117, 125, 0.4);
    }
    .model-selection-buttons .stButton>button.selected {
        background-color: #28a745; /* Green for selected model */
        box-shadow: 0 6px 15px rgba(40, 167, 69, 0.3);
    }
    .model-selection-buttons .stButton>button.selected:hover {
        background-color: #218838;
        box-shadow: 0 8px 20px rgba(40, 167, 69, 0.4);
    }
    </style>
""", unsafe_allow_html=True)
st.title("Turing Test challenge 🤖 vs 👤")


if 'score' not in st.session_state:
    st.session_state.score = 0
if 'current_round' not in st.session_state:
    st.session_state.current_round = 0
if 'answers_shuffled' not in st.session_state:
    st.session_state.answers_shuffled = []
if 'correct_answer_index' not in st.session_state:
    st.session_state.correct_answer_index = -1
if 'user_choice' not in st.session_state:
    st.session_state.user_choice = None
if 'feedback_message' not in st.session_state:
    st.session_state.feedback_message = ""
if 'loading_ai_response' not in st.session_state:
    st.session_state.loading_ai_response = False
if 'message_box_visible' not in st.session_state:
    st.session_state.message_box_visible = False
if 'message_box_content' not in st.session_state:
    st.session_state.message_box_content = ""
if 'api_key_entered' not in st.session_state:
    st.session_state.api_key_entered = False
if 'selected_model' not in st.session_state:
    st.session_state.selected_model = None 
if 'api_key' not in st.session_state:
    st.session_state.api_key = ""
if 'api_error_occurred' not in st.session_state: 
    st.session_state.api_error_occurred = False

def reset_game():
    st.session_state.score=0
    st.session_state.current_round=0
    st.session_state.answer_shuffled=[]
    st.session_state.correct_answer_index=-1
    st.session_state.user_choice = None
    st.session_state.feedback_message = ""
    st.session_state.loading_ai_response = False
    st.session_state.message_box_visible = False
    st.session_state.message_box_content = ""
    st.session_state.api_error_occurred = False
def stop_game():
    reset_game()
    st.session_state.api_key_entered=False
    st.session_state.selected_model=None
    st.session_state.api_key=""
    st.rerun()

def start_new_round():
    if st.session_state.current_round>=len(QUESTIONS):
        st.session_state.feedback_message="Game Over! You've completed all questions"
        return
    
    quest_data=QUESTIONS[st.session_state.current_round]
    quest_text=quest_data["question"]
    hum_ans=quest_data["human_answer"]

    ai_prompt = (
    f"You are participating in a Turing Test. Your goal is to sound like a plain, practical human. "
    f"Provide a concise, natural, and conversational response, typically 1-2 sentences long. "
    f"Avoid conversational fillers like 'Hmm, that's a good question,' 'As an AI language model,' "
    f"'I'm glad you asked,' or similar overly chatty phrases. Do not use Gen Z slang or emojis. "
    f"Be direct and answer as a normal person would. "
    f"Answer the following question: '{quest_text}'"
)

    with st.spinner(f"Generating AI response using {st.session_state.selected_model.capitalize()}..."):
        ai_answer=None
        if st.session_state.selected_model== "gemini":
            ai_answer=get_gem_resp(ai_prompt,st.session_state.api_key)
        elif st.session_state.selected_model== "openai":
            ai_answer=get_openai_Resp(ai_prompt,st.session_state.api_key)
    if st.session_state.api_error_occurred:
        stop_game()
        return
    if ai_answer is None:
        return
    answers=[
        {"text":hum_ans,"type":"human"},
        {"text":ai_answer,"type":"ai"}
    ]
    random.shuffle(answers)
    st.session_state.answers_shuffled=answers

    for i,ans in enumerate(answers):
        if ans["type"]=="ai":
            st.session_state.correct_answer_index=i
            break
    st.session_state.user_choice=None
    st.session_state.feedback_message=""
    st.rerun()

def submit_guess():
    if st.session_state.user_choice is None:
        st.session_state.message_box_content="Pls select an answer before submitting"
        st.session_state.message_box_visible=True
        return
    st.session_state.message_box_visible=False
    if st.session_state.user_choice==st.session_state.correct_answer_index:
        st.session_state.score+=1
        st.session_state.feedback_message="Correct! You identified AI"
    else:
        st.session_state.feedback_message="Incorrect. That was human answer"
    
    st.session_state.current_round+=1
    st.rerun()

if not st.session_state.api_key_entered:
    st.markdown("Enter your API Key")
    st.info("To start the game, please enter your API key for either Google Gemini or OpenAI. This key is used only for generating AI responses and is not stored.")
    st.session_state.api_key=st.text_input("API Key",type="password",key="api_key_input")
    st.markdown("Choose your AI model")
    col1,col2=st.columns(2)
    with col1:
        gem_butt="selected" if st.session_state.selected_model=="gemini" else ""
        if st.button("Play with Gemini",key="gemini_button"):
            if st.session_state.api_key:
                st.session_state.selected_model='gemini'
                st.session_state.api_key_entered=True
                reset_game()
                st.rerun()
            else:
                st.session_state.message_box_content="Pls enter your API key first"
                st.session_state.message_box_visible=True
    with col2:
        openai_butt="selected" if st.session_state.selected_model=="openai" else ""
        if st.button("Play with OpenAI",key="openai_button"):
            if st.session_state.api_key:
                st.session_state.selected_model= "openai"
                st.session_state.api_key_entered=True
                reset_game()
                st.rerun()
            else:
                st.session_state.message_box_content="Pls enter your api key first"
                st.session_state.message_box_visible=True
    if st.session_state.message_box_visible:
        st.markdown(f"<div class='message-box'>{st.session_state.message_box_content}</div>", unsafe_allow_html=True)
else:
    st.markdown(f"<div class='score-box'>Score: {st.session_state.score} / {st.session_state.current_round}</div>", unsafe_allow_html=True)
    model_display_name = st.session_state.selected_model.capitalize() if st.session_state.selected_model else "Unknown"
    st.markdown(f"<p style='text-align: center; font-size: 1.1em; color: #555;'>Playing with: <b>{model_display_name}</b></p>", unsafe_allow_html=True)    
    st.button("🛑 Stop Game and Reset", on_click=stop_game, key="stop_game_button", help="End the current game and return to the API key input screen.", type="secondary")
    if st.session_state.message_box_visible:
        st.markdown(f"<div class='message-box'>{st.session_state.message_box_content}</div>", unsafe_allow_html=True)
    if st.session_state.feedback_message:
        feedback_class = "correct-feedback" if "Correct" in st.session_state.feedback_message else "incorrect-feedback"
        st.markdown(f"<div class='{feedback_class}'>{st.session_state.feedback_message}</div>", unsafe_allow_html=True)
        
        if st.session_state.current_round < len(QUESTIONS):
            if st.button("Next Question", key="next_question_button"):
                st.session_state.feedback_message = "" 
                st.session_state.answers_shuffled = [] 
                st.rerun()
        else:
            st.markdown(f"<div class='message-box'>🎉 Game Over! Final Score: {st.session_state.score} / {len(QUESTIONS)} 🎉</div>", unsafe_allow_html=True)
            if st.button("Play Again", key="play_again_button"):
                reset_game()
                st.rerun()
            if st.button("Change Model / API Key", key="change_model_button"):
                st.session_state.api_key_entered = False
                st.session_state.selected_model = None
                st.session_state.api_key = ""
                reset_game()
                st.rerun()
    if not st.session_state.loading_ai_response and st.session_state.current_round < len(QUESTIONS) and not st.session_state.feedback_message and not st.session_state.api_error_occurred:
        current_question_data = QUESTIONS[st.session_state.current_round]
        st.markdown(f"<div class='question-box'>Question: {current_question_data['question']}</div>", unsafe_allow_html=True)

        if not st.session_state.answers_shuffled:
            start_new_round()
        else:
            options = [f"A: {st.session_state.answers_shuffled[0]['text']}",
                       f"B: {st.session_state.answers_shuffled[1]['text']}"]
            user_choice_display = st.radio(
                "Which answer do you think was generated by the AI?",
                options,
                index=None,
                key=f"round_radio_{st.session_state.current_round}",
                format_func=lambda x: x[3:] 
            )
            if user_choice_display == options[0]:
                st.session_state.user_choice = 0
            elif user_choice_display == options[1]:
                st.session_state.user_choice = 1
            else:
                st.session_state.user_choice = None 

            st.button("Submit Guess", on_click=submit_guess, key="submit_guess_button")
    if st.session_state.api_key_entered and st.session_state.current_round == 0 and not st.session_state.answers_shuffled and not st.session_state.loading_ai_response and not st.session_state.feedback_message and not st.session_state.api_error_occurred:
        st.button("Start Game", on_click=start_new_round, key="start_game_button")