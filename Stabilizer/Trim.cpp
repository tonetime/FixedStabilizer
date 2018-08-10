#include <vector>
#include <opencv2/opencv.hpp>
#include <opencv2/imgproc.hpp>
#include "Trim.hpp"

/*
 This class handles the nasty business of figuring out how much to trim.
 */

static inline int areaSign(cv::Point2f a, cv::Point2f b, cv::Point2f c) {
    double area = (b-a).cross(c-a);
    if (area < -1e-5) return -1;
    if (area > 1e-5) return 1;
    return 0;
}
static inline bool segmentsIntersect(cv::Point2f a, cv::Point2f b, cv::Point2f c, cv::Point2f d) {
    return areaSign(a,b,c) * areaSign(a,b,d) < 0 &&
    areaSign(c,d,a) * areaSign(c,d,b) < 0;
}

static inline bool isRectInside(const cv::Point2f a[4], const cv::Point2f b[4]) {
    for (int i = 0; i < 4; ++i)
        if (b[i].x > a[0].x && b[i].x < a[2].x && b[i].y > a[0].y && b[i].y < a[2].y)
            return false;
    for (int i = 0; i < 4; ++i)
        for (int j = 0; j < 4; ++j)
            if (segmentsIntersect(a[i], a[(i+1)%4], b[j], b[(j+1)%4]))
                return false;
    return true;
}

Trim::Trim() {
}

float Trim::estimateOptimalTrimRatio(const cv::Mat &M, cv::Size size) {
    CV_Assert(M.size() == cv::Size(3,3) && M.type() == CV_32F);
    
    const float w = static_cast<float>(size.width);
    const float h = static_cast<float>(size.height);
    cv::Mat_<float> M_(M);
    cv::Point2f pt[4] = { cv::Point2f(0,0), cv::Point2f(w,0), cv::Point2f(w,h), cv::Point2f(0,h)};
    cv::Point2f Mpt[4];
    float z;
    
    for (int i = 0; i < 4; ++i)
    {
        Mpt[i].x = M_(0,0)*pt[i].x + M_(0,1)*pt[i].y + M_(0,2);
        Mpt[i].y = M_(1,0)*pt[i].x + M_(1,1)*pt[i].y + M_(1,2);
        z = M_(2,0)*pt[i].x + M_(2,1)*pt[i].y + M_(2,2);
        Mpt[i].x /= z;
        Mpt[i].y /= z;
    }
    
    float l = 0, r = 0.5f;
    while (r - l > 1e-3f)
    {
        float t = (l + r) * 0.5f;
        float dx = floor(w * t);
        float dy = floor(h * t);
        pt[0] = cv::Point2f(dx, dy);
        pt[1] = cv::Point2f(w - dx, dy);
        pt[2] = cv::Point2f(w - dx, h - dy);
        pt[3] = cv::Point2f(dx, h - dy);
        if (isRectInside(pt, Mpt))
            r = t;
        else
            l = t;
    }
    return r;
}


static cv::Mat trimFrame(float trimRatio, cv::Mat frame) {
    int dx = static_cast<int>(floor(trimRatio * frame.cols));
    int dy = static_cast<int>(floor(trimRatio * frame.rows));
    return frame(cv::Rect(dx, dy, frame.cols - 2*dx, frame.rows - 2*dy));
}

float estimateOptimalTrimRatio2(const cv::Mat &M, cv::Size size) {
    CV_Assert(M.size() == cv::Size(3,3) && M.type() == CV_32F);
    
    const float w = static_cast<float>(size.width);
    const float h = static_cast<float>(size.height);
    cv::Mat_<float> M_(M);
    cv::Point2f pt[4] = { cv::Point2f(0,0), cv::Point2f(w,0), cv::Point2f(w,h), cv::Point2f(0,h)};
    cv::Point2f Mpt[4];
    float z;
    
    for (int i = 0; i < 4; ++i)
    {
        Mpt[i].x = M_(0,0)*pt[i].x + M_(0,1)*pt[i].y + M_(0,2);
        Mpt[i].y = M_(1,0)*pt[i].x + M_(1,1)*pt[i].y + M_(1,2);
        z = M_(2,0)*pt[i].x + M_(2,1)*pt[i].y + M_(2,2);
        Mpt[i].x /= z;
        Mpt[i].y /= z;
    }
    
    float l = 0, r = 0.5f;
    while (r - l > 1e-3f)
    {
        float t = (l + r) * 0.5f;
        float dx = floor(w * t);
        float dy = floor(h * t);
        pt[0] = cv::Point2f(dx, dy);
        pt[1] = cv::Point2f(w - dx, dy);
        pt[2] = cv::Point2f(w - dx, h - dy);
        pt[3] = cv::Point2f(dx, h - dy);
        if (isRectInside(pt, Mpt))
            r = t;
        else
            l = t;
    }
    return r;
}



