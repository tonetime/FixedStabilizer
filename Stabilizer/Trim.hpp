

#ifndef Trim_hpp
#define Trim_hpp
#import <vector>
#include <stdio.h>

class PyramidHold {
public:
    int indx;
    std::vector<cv::Mat> pyramid;
    PyramidHold() { }
    PyramidHold(int x,std::vector<cv::Mat> m)
    {
        indx=x;
        pyramid=m;
    }
};

class MatProc {
public:
    int indx;
    cv::Mat mat;
    MatProc() { }
    
    MatProc(int x,cv::Mat m)
    {
        indx=x;
        mat=m;
    }
};

class Trim {
public:
    Trim();
    float estimateOptimalTrimRatio(const cv::Mat &M, cv::Size size);
};
#endif /* Trim_hpp */
