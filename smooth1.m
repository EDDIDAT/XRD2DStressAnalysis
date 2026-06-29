function y = smooth1(x, w)
x = x(:);
w = max(1, round(w));
if mod(w,2)==0, w = w + 1; end
if w == 1
    y = x;
    return;
end
k = ones(w,1) / w;
y = conv(x, k, 'same');
end