# -*- coding: utf-8 -*-
"""
Created on Fri Mar  7 00:50:35 2025

@author: e2ken
"""

import numpy as np
import pandas as pd

# 포지션별 주요 능력치 설정
position_attributes = {
    "GK": ["반사 신경", "다이빙", "핸들링", "1대1 방어"],
    "CB": ["태클", "헤딩", "인터셉트", "힘"],
    "RB": ["속도", "태클", "크로스", "스태미너"],
    "LB": ["속도", "태클", "크로스", "스태미너"],
    "CDM": ["태클", "인터셉트", "경기 지능", "위치 선정"], 
    "CM": ["패스", "경기 지능", "퍼스트 터치", "위치 선정"], 
    "CAM": ["패스", "드리블", "공간 침투", "공격 성향"],
    "RW": ["속도", "드리블", "크로스", "민첩성"],
    "LW": ["속도", "드리블", "크로스", "민첩성"],
    "ST": ["슛 정확도", "헤딩", "공간 침투", "균형 감각"], 
}

position_secondary_attributes = {
    "GK": ["킥 능력", "반응 속도", "펀칭"],
    "CB": ["침착함", "균형감각", "패스"],
    "RB": ["인터셉트", "드리블", "민첩성"], 
    "LB": ["인터셉트", "드리블", "민첩성"], 
    "CDM": ["팀워크", "수비 성향", "스태미너"], 
    "CM": ["킥 능력", "공간 침투", "체력 회복력"],
    "CAM": ["슛 정확도", "크로스", "위치 선정"],
    "RW": ["슛 정확도", "퍼스트 터치", "가속력"],
    "LW": ["슛 정확도", "퍼스트 터치", "가속력"],
    "ST": ["가속도", "공격 성향", "위치 선정"],
}

#포지션별 실제 비율
position_distribution = {
    "GK": 0.1,
    "CB": 0.2,
    "RB": 0.1,
    "LB": 0.1,
    "CDM": 0.1,
    "CM": 0.15,
    "CAM": 0.08,
    "RW": 0.07,
    "LW": 0.07,
    "ST": 0.08,
}

# 확률 값이 정확히 1인지 확인 후 보정
prob_sum = sum(position_distribution.values())
if prob_sum != 1.0:
    position_distribution = {k: v / prob_sum for k, v in position_distribution.items()}


# 모든 능력치 리스트 (중복 제거)
all_attributes = list(set(sum(position_attributes.values(), [])) | {
'태클', '속도', '위치 선정', '1대1 방어', '민첩성', '반사 신경', '펀칭',
       '수비 성향', '다이빙', '인터셉트', '크로스', '슛 정확도', '가속력', '팀워크', '스태미너',
       '드리블', '균형감각', '공간 침투', '리더십', '패스', '킥 능력', '침착함', '헤딩', '경기 지능',
       '핸들링', '점프력', '공격 성향', '퍼스트 터치', '반응 속도', '힘' 
})

# FIFA 랭킹 100개국 리스트 (상위 국가일수록 높은 확률 배정)
fifa_ranking_100 = [
    "Argentina", "France", "Brazil", "England", "Belgium", "Croatia", "Netherlands", "Italy", "Portugal", "Spain",
    "USA", "Mexico", "Germany", "Switzerland", "Morocco", "Uruguay", "Denmark", "Colombia", "Senegal", "Japan",
    "Sweden", "Poland", "Iran", "Serbia", "South Korea", "Ukraine", "Australia", "Chile", "Austria", "Tunisia",
    "Hungary", "Wales", "Algeria", "Russia", "Egypt", "Scotland", "Ecuador", "Nigeria", "Turkey", "Norway",
    "Paraguay", "Slovakia", "Canada", "Czech Republic", "Romania", "Peru", "Greece", "Costa Rica", "Venezuela", "Iceland",
    "Qatar", "Bosnia and Herzegovina", "Ghana", "Saudi Arabia", "Panama", "United Arab Emirates", "Slovenia", "South Africa", "Iraq", "China",
    "Honduras", "Montenegro", "Bulgaria", "Finland", "Jamaica", "Mali", "Israel", "Bolivia", "Gabon", "Uzbekistan",
    "Guinea", "Armenia", "Oman", "El Salvador", "Georgia", "Congo DR", "Benin", "Bahrain", "Uganda", "North Macedonia",
    "Syria", "Haiti", "Curacao", "Zambia", "Belarus", "Lebanon", "Luxembourg", "Equatorial Guinea", "Vietnam", "Madagascar",
    "Kyrgyzstan", "Kenya", "Jordan", "Palestine", "Trinidad and Tobago", "Mauritania", "India", "Central African Republic", "New Zealand", "Cape Verde"
]

# GK 전용 능력치
GK_SPECIFIC_ATTRIBUTES = ["반사 신경", "다이빙", "핸들링", "1대1 방어", "펀칭"]

# 선수 등급 시스템
def get_player_tier(avg_rating):
    if avg_rating < 60:
        return "N (Normal)"
    elif avg_rating < 70:
        return "S (Special)"
    elif avg_rating < 80:
        return "R (Rare)"
    elif avg_rating < 90:
        return "W (World Class)"
    else:
        return "G (GOAT)"
position = 'CM'
index = 7
# 주요 능력치와 보조 능력치를 분리하여 반영
def generate_random_player(index, position):
    main_attributes = []  # 포지션별 주요 능력치 리스트
    secondary_attributes = []  # 포지션별 보조 능력치 리스트
    player = {"포지션": position, "이름": f"A{index + 1}"}

    for attr in all_attributes:
        if attr in position_attributes.get(position, []):
            # 주요 능력치는 평균 70, 표준편차 14, 최대 99 (포지션별 핵심 능력 강화)
            value = int(np.clip(np.random.normal(70, 30), 38, 99))
            main_attributes.append(value)  # 주요 능력치 저장
        elif attr in position_secondary_attributes.get(position, []):
            # 보조 능력치는 평균 60, 표준편차 15, 최대 95 (보조 능력은 더 낮게 설정)
            value = int(np.clip(np.random.normal(60, 20), 35, 90))
            secondary_attributes.append(value)  # 보조 능력치 저장
        else:
            # 기타 능력치는 더 낮은 범위에서 생성
            value = int(np.clip(np.random.normal(35, 20), 1, 80))
        
        player[attr] = value
    
    avg_main = np.mean(main_attributes) * 0.7 if main_attributes else 0
    avg_secondary = np.mean(secondary_attributes) * 0.3 if secondary_attributes else 0
    avg_weighted_rating = avg_main + avg_secondary if main_attributes or secondary_attributes else 0
    player["가중 평균 능력"] = round(avg_weighted_rating, 1)
    player["등급"] = get_player_tier(avg_weighted_rating)

    # 상위 능력치일수록 상위 국가에 배정될 확률 증가
    '''
    rank_index = min(int(avg_weighted_rating // 1), len(fifa_ranking_100) - 1)  # 10 단위 구간 배정
    rank_weights = np.linspace(2, 1, len(fifa_ranking_100))  # 상위 국가일수록 높은 가중치
    player["국가"] = np.random.choice(fifa_ranking_100[:rank_index+1], p=rank_weights[:rank_index+1] / sum(rank_weights[:rank_index+1]))
    '''
    rank_index = min(int(avg_weighted_rating // 1), len(fifa_ranking_100) - 1)  # 10 단위 구간 배정
    rank_weights = np.exp(np.linspace(10, 1, len(fifa_ranking_100)))
    probabilities = rank_weights[:rank_index+1] / sum(rank_weights[:rank_index+1])
    player["국가"] = np.random.choice(fifa_ranking_100[:rank_index+1], p=probabilities)
    return player

# 10,000명의 랜덤 선수 생성
num_players_test = 10000
positions = list(position_distribution.keys())
position_choices = np.random.choice(positions, num_players_test, p=list(position_distribution.values()))
players = [generate_random_player(i, position_choices[i]) for i in range(num_players_test)]

# 데이터프레임 생성
df_players = pd.DataFrame(players)
df_players['등급'].value_counts()


#df_players['포지션'].value_counts()

df_players.columns
df_nation = df_players[['국가', '가중 평균 능력']].groupby('국가').mean().reset_index()
df_count = df_players[['국가', '가중 평균 능력']].groupby('국가').count().reset_index()

df_result = pd.merge(df_nation, df_count, how='left',on='국가')